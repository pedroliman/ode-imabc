import io;
import sys;
import files;
import location;
import string;
import EQR;
import R;
import assert;
import python;
import unix;
import stats;

string emews_root = getenv("EMEWS_PROJECT_ROOT");
string turbine_output = getenv("TURBINE_OUTPUT");

string resident_work_ranks = getenv("RESIDENT_WORK_RANKS");
string r_ranks[] = split(resident_work_ranks,",");

string algo_file = argv("algo_file");
string algo_params_file = argv("algo_params_file");

file model_sh = input(emews_root+"/scripts/crcspin.sh");

string scenario = argv("scenario");

// string run_model_template = """
// import json
// import run_model
// json_params = '%s'
// json_lb = '%s'
// json_ub = '%s'
// psa_location = '%s'
// turbine_output = '%s'
// # print(json_lb, flush=True)
// # print(json_ub, flush=True)
// res = run_model.run(psa_location, turbine_output, json_params, json_lb, json_ub)
// json_res = json.dumps(res)
// """;

// Note that this is python code. The workflow does need python to parse the parameters.

string parse_params_template = """
import json
param_list = json.loads('%s')
all_params = ''
for p_map in param_list:
    instance = p_map.pop('instance')
    params = '{}!{}'.format(instance, json.dumps(p_map))
    if len(all_params) > 0:
      all_params = '{};{}'.format(all_params, params)
    else:
      all_params = params
""";

app (file out, file err) run(string params, string json_lb, string json_ub, string result_file)
{
    "bash" model_sh params json_lb json_ub scenario result_file @stdout=out @stderr=err;
}


app (void o) rm(string filename) {
    "rm" filename;
}

(string result) obj(string params_str, string json_lb, string json_ub, string tmp_dir) {
    string ps[] = split(params_str, "!");
    string instance = ps[0];
    string params = ps[1];

    string out_f = "%s/%s_out.txt" % (tmp_dir, instance);
    string err_f = "%s/%s_err.txt" % (tmp_dir, instance);
    string result_file = "%s/results/result_%s.json" % (turbine_output, instance);
    file out <out_f>;
    file err <err_f>;
    (out,err) = run(params, json_lb, json_ub, result_file) =>
    result = file_lines(input(result_file))[0] =>
    rm(result_file) =>
    rm(out_f) =>
    rm(err_f);
}

(void v) loop(location ME, int ME_rank) {

    for (boolean b = true, int i = 1;
       b;
       b=c, i = i + 1)
    {
        string payload_str =  EQR_get(ME);
        string payload[] = split(payload_str, "|");
        string payload_type = payload[0];
        boolean c;

        if (payload_type == "DONE") {
            string finals =  EQR_get(ME);
            printf("Results: %s", finals) =>
            v = make_void() =>
            c = false;

        } else if (payload_type == "EQR_ABORT") {
            printf("EQR aborted: see output for R error") =>
            string why = EQR_get(ME);
            printf("%s", why) =>
            v = propagate() =>
            c = false;
        } else {
            if (payload_type == "doEMEWS") {
                // printf("Running doEMEWS");
                // string doe_result[] = run_do_emews(payload, node_locations);
                // string doe_result[] = run_do_emews(payload);
                // printf(join(doe_result, ";"));
                // EQR_put(ME, join(doe_result, ";")) => c = true;
            } else {
                // printf("%s", payload_str);
                string results[];
                string vals[] = split(payload_str, "|");
                string param_code = parse_params_template % (vals[0]);
                string json_params[] = split(python_persist(param_code, "all_params"), ";");
                json_lb = vals[1];
                json_ub = vals[2];
                string tmp_dir = "%s/tmp" % turbine_output;
                foreach params, j in json_params {
                    results[j] = obj(params, json_lb, json_ub, tmp_dir);
                }
                string res = join(results, ";");
                EQR_put(ME, res) => c = true;
            }
        }
    }
}


(void o) start(int ME_rank) {
    location ME = locationFromRank(ME_rank);
    //string algorithm = strcat(emews_root, "/R/easyabc.R");
    EQR_init_script(ME, algo_file) =>
    EQR_get(ME) =>
    EQR_put(ME, algo_params_file) =>
    loop(ME, ME_rank) => {
        EQR_stop(ME) =>
        EQR_delete_R(ME);
        o = propagate();
    }
}

// deletes the specified directory
app (void o) rm_dir(string dirname) {
    "rm" "-rf" dirname;
}

main() {

    assert(strlen(emews_root) > 0, "Set EMEWS_PROJECT_ROOT!");

    int ME_ranks[];
    foreach r_rank, i in r_ranks {
      ME_ranks[i] = toint(r_rank);
    }

    foreach ME_rank, i in ME_ranks {
    start(ME_rank) =>
        printf("End rank: %d", ME_rank);
    }
}
