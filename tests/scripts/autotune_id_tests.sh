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
##### Script for validating the autotune and autotune config object id #####

# Get the absolute path of current directory
CURRENT_DIR="$(dirname "$(realpath "$0")")"
pushd ${CURRENT_DIR}/.. >> setup.log

autotune_id=("get_listapplication_json_app" "get_listapplication_json" "get_listapplayer_json_app" "get_listapplayer_json" "get_list_autotune_tunables_json_sla_layer" "get_list_autotune_tunables_json_sla" "get_list_autotune_tunables_json" "get_listapptunables_json_app_layer" "get_listapptunables_json_app" "get_listapptunables_json")
old_autotune_id=("get_listapplication_json_app" "get_listapplication_json" "get_listapplayer_json_app" "get_listapplayer_json" "get_list_autotune_tunables_json_sla_layer" "get_list_autotune_tunables_json_sla" "get_list_autotune_tunables_json" "get_listapptunables_json_app_layer" "get_listapptunables_json_app" "get_listapptunables_json")
declare -A autotune_id_expected_behaviour
autotune_id_expected_behaviour=([check_uniqueness]="Check if the autotune objects has unique id")
function update_autotune_yaml() {
	find=$1
	replace=$2
	yaml=$3
	sed -i 's/'${find}'/'${replace}'/g' ${yaml}
	echo ""
}
# validate autotune object id 
function autotune_id_tests() {
	start_time=$(get_date)
	FAILED_CASES=()
	TESTS_FAILED=0
	TESTS_PASSED=0
	TESTS=0
	autotune_id_tests=( "re_apply") #"check_uniqueness" "update_app_autotune_yaml" "multiple_apps")
	
	if [ ! -z "${testcase}" ]; then
		check_test_case "autotune_id"
	fi
	
	# create the result directory for given testsuite
	echo ""
	TEST_SUITE_DIR="${RESULTS}/autotune_id_tests"
	AUTOTUNE_YAML="${APP_REPO}/galaxies/autotune"
	
	mkdir -p ${TEST_SUITE_DIR}
	
	echo ""
	((TOTAL_TEST_SUITES++))
	
	echo ""
	echo "******************* Executing test suite ${FUNCNAME} ****************"
	echo ""

	# If testcase is not specified run all tests	
	if [ -z "${testcase}" ]; then
		testtorun=("${autotune_id_tests[@]}")
	else
		testtorun=${testcase}
	fi
	
	for test in "${testtorun[@]}"
	do
		${test}	
	done
	
	if [ "${TESTS_FAILED}" -ne "0" ]; then
		FAILED_TEST_SUITE+=(${FUNCNAME})
	fi 
	
	# Cleanup autotune
	autotune_cleanup  | tee -a ${LOG}
	
	end_time=$(get_date)
	elapsed_time=$(time_diff "${start_time}" "${end_time}")
	
	# print the testsuite summary
	testsuitesummary ${FUNCNAME} ${elapsed_time} ${FAILED_CASES} 
}

function validate_id() {
	_object_=$1
	expected_flag=$2
	id=$3
	flag=0
	((TOTAL_TESTS++)) 
	((TESTS++))
	
	if [ "${_object_}" == "autotune" ]; then
		test_array="${id}"
	else 
		test_array="${autotune_config_id}"
	fi
	
	IFS=' ' read -r -a test_array <<<  ${test_array}
	# If element of test_array is not in seen, then store in seen array
	uniqueNum=$(printf '%s\n' "${test_array[@]}"|awk '!($0 in seen){seen[$0];c++} END {print c}')
	if [ "${uniqueNum}" != "${#test_array[@]}" ]; then
		flag=1		
	fi
	echo "flag is ${expected_flag}"
	if [ "${flag}" -eq "0" ]; then
		((TESTS_PASSED++))
		((TOTAL_TESTS_PASSED++))
		echo "Test passed" | tee -a ${LOG}
	else
		((TESTS_FAILED++))
		((TOTAL_TESTS_FAILED++))
		echo "Test failed" | tee -a ${LOG}
	fi
	echo "Expected behaviour:${autotune_id_expected_behaviour[id_test_name]}"
}

function validate_autotune_id() {
	json=$1
	flag_val=$2
	test_name=$3
	declare -A autotune_id
	get_id autotune
}

function get_id() {
	object=$1
	length=$(cat ${json} | jq '. | length')
	while [ "${length}" -ne 0 ]
	do	
	((length--))
	if [ "${object}" == "autotune" ]; then
		autotune_id[test_name]+=" $(cat ${json} | jq .[${length}].id) "
	else 
		autotuneconfig_id[test_name]+=$(cat ${json} | jq .[${length}].layers[].id)
	fi
	done
#	for id in "${autotune_id[@]}"
#	do
#		autotune_id=( "${autotune_id[id]/get*/}" )
#	done
	echo ""
	echo "autotune_id for ${test_name} is ${autotune_id[test_name]}"
}

function validate_apis() {
	id_test_name=$1
	# get autotune pod log
	autotune_pod=$(kubectl get pod -n monitoring | grep autotune | cut -d " " -f1)
	pod_log_msg=$(kubectl logs ${autotune_pod} -n monitoring)
	echo "${pod_log_msg}" > "${AUTOTUNE_LOG}"
	
	LOG_DIR="${TEST_DIR}/${autotune_id[0]}"
	mkdir -p ${LOG_DIR}
	# listapplication for specific application
	get_listapplication_json ${application_name} 
	validate_autotune_id ${json_file} ${flag_value} ${autotune_id[0]}
	
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"| tee -a ${LOG}
	
	LOG_DIR="${TEST_DIR}/${autotune_id[1]}"
	mkdir -p ${LOG_DIR}
	# listapplication for all applications
	get_listapplication_json 
	validate_autotune_id ${json_file} ${flag_value} ${autotune_id[1]}
	
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"| tee -a ${LOG}
	if [ "${TESTS_FAILED}" -ne "0" ]; then
		FAILED_CASES+=(${id_test_name})
	fi
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"| tee -a ${LOG}
}

function perform_id_test() {
	id_test_name=$1
	flag_value=$2
	sla_class="response_time"
	layer="container"
	
	TEST_DIR="${TEST_SUITE_DIR}/${id_test_name}"
	mkdir ${TEST_DIR}
	SETUP="${TEST_DIR}/setup.log"
	AUTOTUNE_LOG="${TEST_DIR}/${id_test_name}_autotune.log"
	LOG="${TEST_SUITE_DIR}/${id_test_name}.log"
	yaml_dir="${TEST_DIR}/yamls"
	mkdir -p ${yaml_dir}
	
	echo ""
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | tee -a ${LOG}
	echo "                    Running Test ${id_test_name}" | tee -a ${LOG}
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"| tee -a ${LOG}
	
	# create the autotune setup
	echo "Setting up autotune..." | tee -a ${LOG}
	setup >> ${SETUP} 2>&1
	echo "Setting up autotune...Done" | tee -a ${LOG}
	
	# Giving a sleep for autotune pod to be up and running
#	sleep 10
	
	# Deploy petclinic application instances	
#	deploy_app ${APP_REPO} galaxies 3

	# Sleep for sometime for application pods to be up
	sleep 5

	# Get the application pods
	application_name=$(kubectl get pod | grep galaxies-sample-0 | awk '{print $1}')
	app_pod_names=$(kubectl get pod | grep galaxies | cut -d " " -f1| tr '\n' ' ')
	autotune_names=("galaxies-autotune-0"  "galaxies-autotune-1" "galaxies-autotune-2")
	
	# Add label to your application pods for autotune to monitor
	label_names=("galaxies-deployment-0" "galaxies-deployment-1" "galaxies-deployment-2")
	label_pods app_pod_names label_names
	
	count=0
	IFS=' ' read -r -a app_pod_names <<<  ${app_pod_names}
	for app in "${app_pod_names[@]}"
	do
		echo "app is ${app}"
		echo "count is ${count}"
		test_yaml="${yaml_dir}/${autotune_names[count]}.yaml"
		sed 's/galaxies-deployment/galaxies-deployment-'${count}'/g' ${AUTOTUNE_YAML}/autotune-app_resp_time.yaml > ${test_yaml}
		sed -i 's/galaxies-autotune/galaxies-autotune-'${count}'/g' ${test_yaml}
		echo -n "Applying autotune yaml ${test_yaml}..." | tee -a ${LOG}
		kubectl apply -f ${test_yaml} >> ${SETUP}
		echo "done" | tee -a ${LOG}
		((count++))
	done 
	
	# form the curl command based on the cluster type
	form_curl_cmd
	
	validate_apis

}

function check_uniqueness() {
	perform_id_test ${FUNCNAME} 
	validate_id autotune 0 ${autotune_id[test_name]}
}

function re_apply() {
	match_array=0
	perform_id_test ${FUNCNAME}
	echo "***********${autotune_id[@]}**********"
	for id in "${autotune_id[@]}"
	do
		echo "----------${id}----------"
		echo "=============${autotune_id[test_name]}======="
		echo "=============${autotune_id[$id]}======="
	done 
	# copy the previous object id value
	declare -A old_autotune_id
	for id in "${autotune_id[@]}"
	do
		echo "+++++++++++${id}+++++++++++++++"
		echo "id is ${autotune_id[id]}"
		old_autotune_id[id]+="${autotune_id[id]} "
		echo "${old_autotune_id[id]}"
	done
	echo "old_autotune_id object ${old_autotune_id[@]}"
	echo "old_autotune_id ${!old_autotune_id[@]}"
	kubectl delete -f ${yaml_dir}
	kubectl apply -f ${yaml_dir}
	validate_apis ${FUNCNAME}
	id_count=0
	echo "autotune ids ${autotune_id[@]}"
	for val in "${!old_autotune_id[@]}"
	do
		echo "old is ${old_autotune_id[$val]}"
		test="${autotune_id[id_count]}"
		echo "test name is ${test}"
		echo "new is ${autotune_id[test]}"
		if [ ${autotune_id[test]} != "${old_autotune_id[val]}" ]; then
			match_array=1
		fi
		((id_count++))
	done
	if [ "${match_array}" -eq 1 ]; then
		echo "test failed"
	else
		echo "test passed"
	fi
}

function update_app_autotune_yaml() {
	perform_id_test ${FUNCNAME}
	test_yaml="${yaml_dir}/${autotune_names[0]}.yaml"
	sed -i 's/response_time/throughput/g' ${test_yaml}
	sed -i 's/minimize/maximize/g' ${test_yaml}
	kubectl apply -f ${test_yaml}
	
}

function multiple_apps() {
	# Deploy
	deploy_app ${APP_REPO} galaxies 3

	# Sleep for sometime for application pods to be up
	sleep 5

	# Get the application pods
	app_pod_names=$(kubectl get pod | grep galaxies | cut -d " " -f1)
	
	perform_id_test ${FUNCNAME}
}
