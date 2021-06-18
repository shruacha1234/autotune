#!/bin/bash
#
# Copyright (c) 2020, 2021 Red Hat, IBM Corporation and others.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
##### Script for validating RM results #####

# Get the absolute path of current directory
CURRENT_DIR="$(dirname "$(realpath "$0")")"
SCRIPTS_DIR="${CURRENT_DIR}"

# Tests directory path
pushd "${CURRENT_DIR}/.." > /dev/null
TEST_DIR_="${PWD}"

# Source the common functions scripts
. ${SCRIPTS_DIR}/rm_constants.sh
. ${SCRIPTS_DIR}/rm_common_functions.sh

# Tests to validate the RM-ML apis
function rm_api_tests() {
	start_time=$(get_date)
	FAILED_CASES=()
	TESTS_FAILED=0
	TESTS_PASSED=0
	TESTS=0
	((TOTAL_TEST_SUITES++))
	input_json="${TEST_DIR_}/resources/em_input_json/petclinic_input.json"

	rm_api_tests=("get_list_exp_invalid_tests" "get_list_exp_valid_tests")
	
	# check if the test case is supported
	if [ ! -z "${testcase}" ]; then
		check_test_case "rm_api"
	fi

	# create the result directory for given testsuite
	echo ""
	TEST_SUITE_DIR="${RESULTS}/rm_api_tests"
	SETUP="${TEST_SUITE_DIR}/setup.log"
	AUTOTUNE_JSONS_DIR="${TEST_SUITE_DIR}/autotune_jsons"
	AUTOTUNE_CONFIG_JSONS_DIR="${TEST_SUITE_DIR}/autotuneconfig_jsons"
	YAML="${APP_REPO}/autotune/autotune-http_resp_time.yaml"
	
	mkdir -p ${TEST_SUITE_DIR}
	mkdir -p ${AUTOTUNE_JSONS_DIR}
	mkdir -p ${AUTOTUNE_CONFIG_JSONS_DIR}
	
	# If testcase is not specified run all tests	
	if [ -z "${testcase}" ]; then
		testtorun=("${rm_api_tests[@]}")
	else
		testtorun=${testcase}
	fi
	
	declare -A layer_configs=([petclinic-deployment-0]="container" [petclinic-deployment-1]="container" [petclinic-deployment-2]="container")
	deployments=("petclinic-deployment-0" "petclinic-deployment-1" "petclinic-deployment-2")
	autotune_names=("petclinic-autotune-0")
	
	echo ""
	echo "************************* Executing test suite ${FUNCNAME} **********************"
	echo ""
		
	#create autotune setup
	echo -n "Deploying autotune..."
	setup ${CONFIGMAP} >> ${SETUP} 2>&1
	echo "done"
	
	# Giving a sleep for autotune pod to be up and running
	sleep 10
	
	NAMESPACE="monitoring"
	# Get the autotune config names applied by default
	autotune_config_names=$(kubectl get autotuneconfig -n ${NAMESPACE} --no-headers=true | cut -d " " -f1 | tr "\n" " ")
	IFS=' ' read -r -a autotune_config_names <<<  ${autotune_config_names}

	# form the curl command based on the cluster type
	form_curl_cmd

	# Deploy petclinic application instances	
	deploy_app ${APP_REPO} petclinic 1

	# Sleep for sometime for application pods to be up
	sleep 5

	# Get the application pods
	application_name=$(kubectl get pod | grep petclinic-sample-0 | awk '{print $1}')
	app_pod_names=$(kubectl get pod | grep petclinic | cut -d " " -f1)
	
	# Create yaml directory
	TEST_YAML_DIR="${TEST_SUITE_DIR}/yamls"
	mkdir -p ${TEST_YAML_DIR}
	autotune_test_yaml="${TEST_YAML_DIR}/${autotune_names[0]}.yaml"
	
	# Copy autotune yaml from benchmark repo
	cp "${YAML}" "${autotune_test_yaml}"
	sed -i 's/petclinic-deployment/'${deployments[0]}'/g' ${autotune_test_yaml}
	
	# Get the autotune jsons and autotune config jsons
	get_autotune_jsons ${AUTOTUNE_JSONS_DIR} ${YAML_PATH} ${autotune_names[@]}
	get_autotune_config_jsons ${AUTOTUNE_CONFIG_JSONS_DIR} ${autotune_config_names[@]}
	
	for test in "${testtorun[@]}"
	do
		TEST_DIR="${TEST_SUITE_DIR}/${test}"
		mkdir -p ${TEST_DIR}
		AUTOTUNE_LOG="${TEST_DIR}/${test}_autotune.log"
		LOG="${TEST_SUITE_DIR}/${test}.log"
		input_json_dir="${TEST_DIR}/input_json"
		mkdir -p ${input_json_dir}
		LOG_DIR="${TEST_DIR}"
	
		# Get the searchspace JSON
		get_listapplayer_json "${application_name}"
		exp_id=$(cat  ${json_file} | jq .[].id | tr -d '"')

		echo ""
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | tee -a ${LOG}
		echo "                    Running Test ${test}" | tee -a ${LOG}
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"| tee -a ${LOG}

		echo " " | tee -a ${LOG}
		echo "Test description: ${rm_api_test_description[$test]}" | tee -a ${LOG}
		echo " " | tee -a ${LOG}
	
		${test}
	done

	if [ "${TESTS_FAILED}" -ne "0" ]; then
		FAILED_TEST_SUITE+=(${FUNCNAME})
	fi
	
	# Cleanup the deployed apps
	app_cleanup "petclinic"

	# Cleanup autotune
	autotune_cleanup ${cluster_type}
	
	end_time=$(get_date)
	elapsed_time=$(time_diff "${start_time}" "${end_time}")

	# Remove the duplicates 
	FAILED_CASES=( $(printf '%s\n' "${FAILED_CASES[@]}" | uniq ) )

	# print the testsuite summary
	testsuitesummary ${FUNCNAME} ${elapsed_time} ${FAILED_CASES} 
}

function run_list_exp_test() {
	exp=$1
	exp_id=$2
	curl="curl -H 'Accept: application/json'"
	list_exp_url="http://<URL>:<PORT>/listExperiments"
	case "${exp}" in
		invalid-exp-id)
			get_list_experiments=$(curl -H 'Accept: application/json' ''${list_exp_url}'?experiment_id=xyz&trial_num=2' -w '\n%{http_code}' 2>&1)
			get_list_experiments_cmd="${curl} ''${list_exp_url}'?experiment_id=xyz&trial_num=2' -w '\n%{http_code}'"
			;;
		empty-exp-id)
			get_list_experiments=$(curl -H 'Accept: application/json' ''${list_exp_url}'?experiment_id= &trial_num=2' -w '\n%{http_code}' 2>&1)
			get_list_experiments_cmd="${curl} ''${list_exp_url}'?experiment_id= &trial_num=2' -w '\n%{http_code}'"
			;;
		no-exp-id)
			get_list_experiments=$(curl -H 'Accept: application/json' ''${list_exp_url}'?trial_num=2' -w '\n%{http_code}' 2>&1)
			get_list_experiments_cmd="${curl} ''${list_exp_url}'?trial_num=2' -w '\n%{http_code}'"
			;;
		null-exp-id)
			get_list_experiments=$(curl -H 'Accept: application/json' ''${list_exp_url}'?experiment_id=null&trial_num=2' -w '\n%{http_code}' 2>&1)
			get_list_experiments_cmd="${curl} ''${list_exp_url}'?experiment_id=null&trial_num=2' -w '\n%{http_code}'"
			;;
		invalid-trial-number)
			get_list_experiments=$(curl -H 'Accept: application/json' ''${list_exp_url}'?experiment_id='${exp_id}'&trial_num=xyz' -w '\n%{http_code}' 2>&1)
			get_list_experiments_cmd="${curl} ''${list_exp_url}'?experiment_id='${exp_id}'&trial_num=xyz' -w '\n%{http_code}'"
			;;
		empty-trial-number)
			get_list_experiments=$(curl -H 'Accept: application/json' ''${list_exp_url}'?experiment_id='${exp_id}'&trial_num=' -w '\n%{http_code}' 2>&1)
			get_list_experiments_cmd="${curl} ''${list_exp_url}'?experiment_id='${exp_id}'&trial_num=' -w '\n%{http_code}'"
			;;
		no-trial-number)
			get_list_experiments=$(curl -H 'Accept: application/json' ''${list_exp_url}'?experiment_id='${exp_id}'' -w '\n%{http_code}}' 2>&1)
			get_list_experiments_cmd="${curl} ''${list_exp_url}'?experiment_id='${exp_id}'' -w '\n%{http_code}'"
			;;
		null-trial-number)
			get_list_experiments=$(curl -H 'Accept: application/json' ''${list_exp_url}'?experiment_id='${exp_id}'&trial_num=null' -w '\n%{http_code}' 2>&1)
			get_list_experiments_cmd="${curl} ''${list_exp_url}'?experiment_id='${exp_id}'&trial_num=null' -w '\n%{http_code}'"
			;;
		no-exp-id-trial-number)
			get_list_experiments=$(curl -H 'Accept: application/json' ''${list_exp_url}'?' -w '\n%{http_code}' 2>&1)
			get_list_experiments_cmd="${curl} ''${list_exp_url}'?' -w '\n%{http_code}'"
			;;
		valid-exp-id)
			get_list_experiments=$(curl -H 'Accept: application/json' ''${list_exp_url}'?experiment_id='${exp_id}'' -w '\n%{http_code}' 2>&1)
			get_list_experiments_cmd="${curl} ''${list_exp_url}'?experiment_id='${exp_id}'' -w '\n%{http_code}'"
			;;
		valid-exp-id-trial-number)
			get_list_experiments=$(curl -H 'Accept: application/json' ''${list_exp_url}'?experiment_id='${exp_id}'&trial_num=2' -w '\n%{http_code}' 2>&1)
			get_list_experiments_cmd="${curl} ''${list_exp_url}'?experiment_id='${exp_id}'&trial_num=2' -w '\n%{http_code}'"
			;;
	esac
	echo "command used to query the listExperiments API = ${get_list_experiments_cmd}" | tee -a ${LOG_} ${LOG}
	echo "" | tee -a ${LOG_} ${LOG}

	echo "${get_list_experiments}" >> ${LOG_} ${LOG}
	list_exp_http_code=$(tail -n1 <<< "${get_list_experiments}")
	response=$(echo -e "${get_list_experiments}" | tail -2 | head -1)
	list_exp_response=$(echo ${response} | cut -c 4-)
	echo "${list_exp_response}" > ${result}
}

function get_list_exp_invalid_tests() {
	IFS=' ' read -r -a get_list_exp_invalid_tests <<<  ${rm_ml_api_testscases[$FUNCNAME]}
	for exp_testcase in "${get_list_exp_invalid_tests[@]}"
	do
		LOG_="${TEST_DIR}/${exp_testcase}.log"
		TESTS_="${TEST_DIR}/${exp_testcase}"
		mkdir -p ${TESTS_}
		result="${TESTS_}/listExperiment_result.log"
		
		echo "************************************* ${exp_testcase} Test ****************************************" | tee -a ${LOG_} ${LOG}
		echo " "  | tee -a ${LOG_} ${LOG}
		
		run_list_exp_test "${exp_testcase}" "${exp_id}"

		expected_result_="^4[0-9][0-9]"
		expected_behaviour="RESPONSE_CODE = 4XX BAD REQUEST"

		actual_result="${list_exp_http_code}"
		echo "Actual result: ${actual_result}" >> ${LOG_}
		compare_result ${FUNCNAME} ${expected_result_} "${expected_behaviour}" > >(tee -a "${LOG_}") 2>&1
	done
	
	echo "*************************************************************************************" | tee -a ${LOG_} ${LOG}
}

function validate_list_exp_result() {
	test_name="${FUNCNAME}"
	count=0
#	result="${TEST_DIR}/listExperiment_result.log"
	result="/home/shruthi/rm_result.json"
	autotune_json_="${AUTOTUNE_JSONS_DIR}/${autotune_names[count]}.json"
	container_config="${AUTOTUNE_CONFIG_JSONS_DIR}/container.json"
	validate_list_exp_result_tests=("validate_list_exp_info" "validate_list_exp_trials")
	
	for exp_result_test in "${validate_list_exp_result_tests[@]}"
	do
		echo "______________________________________ ${exp_result_test} ______________________________________" | tee -a ${LOG}
		echo "" | tee -a ${LOG}
		${exp_result_test}
		echo "" | tee -a ${LOG}
		echo "_______________________________________________________________________________________________" | tee -a ${LOG}
		echo "" | tee -a ${LOG}
	done
}

function get_list_exp_valid_tests() {
	IFS=' ' read -r -a get_list_exp_valid_tests <<<  ${rm_ml_api_testscases[$FUNCNAME]}

	for exp_testcase in "${get_list_exp_valid_tests[@]}"
	do
		LOG_="${TEST_DIR}/${exp_testcase}.log"
		TESTS_="${TEST_DIR}/${exp_testcase}"
		mkdir -p ${TESTS_}
		result="${TESTS_}/listExperiment_result.log"
		
		echo "************************************* ${exp_testcase} Test ****************************************" | tee -a ${LOG_} ${LOG}
		echo " "  | tee -a ${LOG_} ${LOG}
		
		run_list_exp_test "${exp_testcase}" "${exp_id}"

		actual_result="${list_exp_http_code}"
		expected_result_="200"
		expected_behaviour="RESPONSE_CODE = 200 OK"
		
		echo "Actual result: ${actual_result}" >> ${LOG_}
		compare_result ${FUNCNAME} ${expected_result_} "${expected_behaviour}" > >(tee -a "${LOG_}") 2>&1

		if [ "${failed}" -eq 0 ]; then
			validate_list_exp_result
		fi
	done
	
	echo "*************************************************************************************" | tee -a ${LOG_} ${LOG}
}
