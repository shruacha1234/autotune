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
##### Common routines for Recommendation manager #####

declare -A expected_exp_details
declare -A actual_exp_details
declare -A trial_metrics_value

function query_list_experiments() {
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
#	echo "${get_list_experiments}" >> ${LOG_} ${LOG}
#	list_exp_http_code=$(tail -n1 <<< "${get_list_experiments}")
#	response=$(echo -e "${get_list_experiments}" | tail -2 | head -1)
#	list_exp_response=$(echo ${response} | cut -c 4-)
#	echo "${list_exp_response}" > ${result}
	list_exp_http_code="200"
}
function get_actual_exp_info() {
	actual_exp_details[experiment_id]=$(cat ${result} | jq .[].experiment_id)
	actual_exp_details[application_name]=$(cat ${result} | jq .[].application_name)
	actual_exp_details[objective_function]=$(cat ${result} | jq .[].objective_function)
	actual_exp_details[sla_class]=$(cat ${result} | jq .[].sla_class)
	actual_exp_details[direction]=$(cat ${result} | jq .[].direction)
}

function get_expected_exp_info() {
	expected_exp_details[experiment_id]=$(cat ${json_file} | jq .[].id)
	expected_exp_details[application_name]="${application_name}"
	expected_exp_details[objective_function]=$(cat ${autotune_json_} | jq .spec.sla.objective_function)
	expected_exp_details[sla_class]=$(cat ${autotune_json_} | jq .spec.sla.sla_class)
	expected_exp_details[direction]=$(cat ${autotune_json_} | jq .spec.sla.direction)
}

function validate_list_exp_info() {
	exp_details=("experiment_id" "application_name" "objective_function" "sla_class" "direction")
	
	get_actual_exp_info 
	get_expected_exp_info
	
	for exp_info in "${exp_details[@]}"
	do
		echo "------------------------------ Matching ${exp_info} ------------------------------" | tee -a ${LOG}
		echo "" | tee -a ${LOG}
		echo "Actual ${exp_info}: ${actual_exp_details[$exp_info]}" | tee -a ${LOG}
		echo "Expected ${exp_info}: ${expected_exp_details[$exp_info]}" | tee -a ${LOG}
		if [ "${actual_exp_details[$exp_info]}" != "${expected_exp_details[$exp_info]}" ]; then
			echo "${exp_info} did not match" | tee -a ${LOG}
			failed=1
		else
			failed=0
			echo "${exp_info} matched" | tee -a ${LOG}
		fi
		echo "" | tee -a ${LOG}
	done

	echo "------------------------------------------------------------------------------------------" | tee -a ${LOG}
	
	expected_behaviour="Experiment details of the result must be same as input"
	display_result "${expected_behaviour}" ${test_name} ${failed}
}

function get_actual_trial_info() {
	actual_trial_details[trial_num]=$(cat ${result} | jq .[].trials[${trial}].trial_num)
	actual_trial_details[trial_run]=$(cat ${result} | jq .[].trials[${trial}].trial_run)
	actual_trial_details[trial_measurement_time]=$(cat ${result} | jq .[].trials[${trial}].trial_measurement_time)
	actual_trial_details[deployment_name]=$(cat ${result} | jq .[].trials[${trial}].training.deployment_name)
}

function get_expected_trial_info() {
	expected_trial_details[trial_num]=$(cat ${input_json} | jq .[].trials[${trial}].trial_num)
	expected_trial_details[trial_run]=$(cat ${input_json} | jq .[].trials[${trial}].trial_run)
	expected_trial_details[trial_measurement_time]=$(cat ${input_json} | jq .[].trials[${trial}].trial_measurement_time)
	expected_trial_details[deployment_name]=$(cat ${input_json} | jq .[].trials[${trial}].training.deployment_name)
}

function validate_trial_details() {
	trial_details=("trial_num" "trial_run" "trial_measurement_time" "deployment_name")
	declare -A expected_trial_details
	declare -A actual_trial_details
	
	get_actual_trial_info
	get_expected_trial_info
	
	for trial in "${trial_details[@]}"
	do
		echo "------------------------------ Matching ${trial} ------------------------------" | tee -a ${LOG}
		echo "" | tee -a ${LOG}
		echo "Actual ${trial}: ${actual_trial_details[$trial]}" | tee -a ${LOG}
		echo "Expected ${exp_info}: ${expected_trial_details[$trial]}" | tee -a ${LOG}
		if [ "${actual_trial_details[$trial]}" != "${expected_trial_details[$trial]}" ]; then
			echo "${trial} did not match" | tee -a ${LOG}
			failed=1
		else
			failed=0
			echo "${trial} matched" | tee -a ${LOG}
		fi
		echo "" | tee -a ${LOG}
	
		expected_behaviour="Trial details of the result must be same as input"
		display_result "${expected_behaviour}" ${test_name} ${failed}
	done

	echo "------------------------------------------------------------------------------------------" | tee -a ${LOG}
	
}

function validate_metric_queries() {
	trial_metrics=".[].trials[${trial}].training.metrics[${count}]"
	declare -A expected_metric_details
	declare -A actual_metric_details
	for metric in "${metric_details[@]}"
	do
		expected_metric_details[$metric]=$(cat ${input_json} | jq ${trial_metrics}.${metric})
		actual_metric_details[$metric]=$(cat ${result} | jq ${trial_metrics}.${metric})
		echo "------------------------------ Matching ${metric} ------------------------------" | tee -a ${LOG}
		echo "" | tee -a ${LOG}
		echo "Actual ${metric}: ${actual_metric_details[$metric]}" | tee -a ${LOG}
		echo "Expected ${metric}: ${expected_metric_details[$metric]}" | tee -a ${LOG}
		if [ "${actual_metric_details[$metric]}" != "${expected_metric_details[$metric]}" ]; then
			echo "${metric} did not match" | tee -a ${LOG}
			failed=1
		else
			failed=0
			echo "${metric} matched" | tee -a ${LOG}
		fi
	
		expected_behaviour="Metric details of the result must be same as input"
		display_result "${expected_behaviour}" ${test_name} ${failed}
	done

	echo "------------------------------------------------------------------------------------------" | tee -a ${LOG}
}

function check_for_non_blank_values() {
	failed=0
	metrics=('"name"' '"query"' '"datasource"' '"score"' '"Error"' '"min"' '"mean"' '"mode"' '"max"' '"95.0"' '"99.0"' '"99.9"' '"99.99"' '"99.999"' '"99.9999"' '"100.0"' '"spike"')
	
	for metric_ in "${metrics[@]}"
	do
		metric_val=$(echo ${trial_metrics_value[$metric_]} | tr -d '"')
		if [ -z "${metric_val}" ]; then
			failed=1
			echo "Metric value for ${metric_} is blank"
			break
		fi
	done
	
	expected_behaviour="Metric values must contain some values it should not blank"
	display_result "${expected_behaviour}" ${test_name} ${failed}
}

function validate_percentile_values() {
	failed=0
	percetile=('"95.0"' '"99.0"' '"99.9"' '"99.99"' '"99.999"' '"99.9999"' '"100.0"')
	p_count=0
	
	# Store the percentile values in an array in the given order
	for p in "${percetile[@]}"
	do
		percentile_values[$p_count]="${trial_metrics_value[$p]}"
		((p_count++))
	done
	
	# Check if the percentile values are in ascending order
	for ((i=0; i<${p_count}-1; i++))
	do
		val1=$(echo ${percentile_values[i]} | tr -d '"')
		val2=$(echo ${percentile_values[i+1]} | tr -d '"')
		if [[ -z "${val1}" || -z "${val2}" ]]; then
			failed=1
			echo "Metric values is blank"
			break
		elif [ $(echo "${val1} > ${val2}" | bc) == "1" ]; then
			failed=1
			break
		fi
	done
	
	expected_behaviour="Values for percentiles has to be in ascending order for 95, 99, ... 99.9999, 100"
	display_result "${expected_behaviour}" ${test_name} ${failed}
	echo "-----------------------------------------------" | tee -a ${LOG}
}

function validate_mean() {
	mean=$(echo ${trial_metrics_value['"mean"']} | tr -d '"')
	nn_percentile=$(echo ${trial_metrics_value['"99.0"']} | tr -d '"')
	
	# Check if the Mean value is blank
	if [ -z "${mean}" ]; then
		failed=1
		echo "Mean value is blank"
	else
		if [ $(echo "${mean} > ${nn_percentile}" | bc) == "1" ]; then
			failed=1
		else
			failed=0
		fi
	fi
	
	expected_behaviour="Mean has to be less than 99 percentile"
	display_result "${expected_behaviour}" ${test_name} ${failed}
}

function vaildate_metrics_values() {
	check_for_non_blank_values
	validate_percentile_values
	validate_mean
}

function validate_trial_metrics() {
	count=0
	metric_details=("name" "query" "datasource")
	metric_length=$(cat ${result} | jq '.[].trials['${trial}'].training.metrics | length')
	
	while [ ${count} -lt ${metric_length} ]
	do
		metric_name=$(cat ${result} | jq .[].trials[${trial}].training.metrics[${count}].name)
		echo "" | tee -a ${LOG} 
		echo "--------------******Validating trial_Metrics for ${metric_name}*****-----------------" | tee -a ${LOG}
		echo "" | tee -a ${LOG} 
		# For each metric store its corresponding values and validate the metrics
		for metric in $(jq '.[].trials['${trial}'].training.metrics['${count}'] | keys | .[]' ${result})
		do
			trial_metrics_value[$metric]=$(cat ${result} | jq .[].trials[${trial}].training.metrics[${count}].${metric})
		done
		
		validate_metric_queries
		vaildate_metrics_values
		((count++))
	done
}

function validate_config_template() {
	config_details="${TEST_DIR_}/resources/rm_result_config_info/rm_result_config_info.json"
	resources="jq .[].trials[${trial}].training.config[0].spec[].spec[].resources"
	env="jq .[].trials[${trial}].training.config[1].spec[].spec[].env"
	cpu_request=$(cat ${input_json} | ${resources}.requests.cpu)
	mem_request=$(cat ${input_json} | ${resources}.requests.memory)
	cpu_limit=$(cat ${input_json} | ${resources}.limits.cpu)
	mem_limit=$(cat ${input_json} | ${resources}.limits.memory)
	expected_json="${TEST_DIR}/expected_config.json"
	
	# Copy the template
	cp "${config_details}" "${expected_json}"
	
	# Replace the resource values with the input
	sed -i 's|"CPUREQUEST$"|'${cpu_request}'|g' ${expected_json}
	sed -i 's|"MEMREQUEST$"|'"${mem_request}"'|g' ${expected_json}
	sed -i 's|"CPULIMITS$"|'${cpu_limit}'|g' ${expected_json}
	sed -i 's|"MEMLIMIT$"|'"${mem_limit}"'|g' ${expected_json}
	
	# Get the env parameters from input json
	env_param=$(cat ${input_json} | jq .[].trials[${trial}].training.config[1].spec[].spec[].env | tr -d '{}' | tr -d '\n')
	
	# Convert env_param to an array. Here comma is our delimiter value
	IFS="," read -a env_param <<< ${env_param}
	
	# Count the number of env parameters
	env_count=${#env_param[@]}
	
	# Append each env parameter to expected json
	for env in "${env_param[@]}"
	do
		match='"env": {'
		# Get the name of the tunable
		e_name=$(echo ${env} | awk '{print $1}' | tr -d ':')
			
		# Get the value of the tunable. Start from front, grep everything after ":"
		e_value="${env#*:}"
		
		if [ "${env_count}" -eq "${#env_param[@]}" ]; then
			sed -i "/${match}/a \                                  \  ${e_name}: ${e_value}" ${expected_json}
		else
			sed -i "/${match}/a \                                  \  ${e_name}: ${e_value}," ${expected_json}
		fi
	
		((env_count--))
	done

	# Compare actual json obtained with the expected json
	compare_json ${actual_json} ${expected_json} ${test_name}
}

function check_tunable_value() {
	tunable_name=$(echo $1 | tr -d '"')
	tunable_upper_bound=$2
	tunable_lower_bound=$3
	flag=0
	
	case "${tunable_name}" in
		memoryRequest)
			tunable_value=$(cat ${actual_json} | jq ${resources_}.requests.memory | tr -d '"Mi')
			;;
		cpuRequest)
			tunable_value=$(cat ${actual_json} | jq ${resources_}.requests.cpu)
			;;
		memoryLimit)
			tunable_value=$(cat ${actual_json} | jq ${resources_}.limits.memory | tr -d '"Mi')
			;;
		cpuLimit)
			tunable_value=$(cat ${actual_json} | jq ${resources_}.limits.cpu)
			;;
	esac
	
 	if [[ $(bc <<< "${tunable_value} >= ${tunable_lower_bound} && ${tunable_value} <= ${tunable_upper_bound}") == 0 ]]; then
 		flag=1
	fi
	
	expected_behaviour="Actual Tunable value should be within the given range"
	display_result "${expected_behaviour}" ${test_name} ${flag}
}

function validate_resource_values() {
	resources_=".[0].spec[].spec[].resources"
	container_json="${AUTOTUNE_CONFIG_JSONS_DIR}/container.json"
	requests=$(cat ${actual_json} | jq ''${resources_}'.requests | length')
	limits=$(cat ${actual_json} | jq ''${resources_}'.limits | length')
	actual_resources_count=$(( $requests + $limits ))
	expected_resources_count=$(cat ${container_json} | jq '.tunables | length')
	
	if [ "${actual_resources_count}" -ne "${expected_resources_count}" ]; then
		flag=1
		expected_behaviour="Number of resource Tunables should match with expected"
		display_result "${expected_behaviour}" ${test_name} ${flag}
	else
		for tunable in $(jq '.tunables | keys | .[]' ${container_json})
		do
			echo "" | tee -a ${LOG}
			tunable_name=$(cat ${container_json} | jq .tunables[${tunable}].name)
			tunable_upper_bound=$(cat ${container_json} | jq .tunables[${tunable}].upper_bound | tr -d '""')
			tunable_lower_bound=$(cat ${container_json} | jq .tunables[${tunable}].lower_bound | tr -d '""')
			check_tunable_value "${tunable_name}" "${tunable_upper_bound}" "${tunable_lower_bound}"
			echo "_____________________________________________________________________" | tee -a ${LOG}
		done
	fi
}

function get_layers() {
	count=0
	for layer in $(jq '.[].layers | keys | .[]' ${json_file})
	do
		layer_name=$(cat ${json_file} | jq .[${count}].layers[].layer_name | tr -d '"')
		
		case "${layer_name}" in
			container)
				validate_resource_values
				;;
			*)
				validate_env
				;;
		esac	
		
		((count++))
	done	
}

function validate_env() {
	expected_env=$(cat ${container_json} | jq .[].trials[${trial}].training.config[1].spec[].spec[].env | tr '\r\n' ' ' | tr -d '{}')
	expected_env_count=
	IFS=',' read -r -a expected_env <<<  ${expected_env}
	actual_env=$(cat ${actual_json} | jq .spec.containers[].env[] | tr '\r\n' ' ' | tr -d '{}')
	IFS=',' read -r -a actual_env <<<  ${actual_env}
	expected_behaviour="Number of tunables in deployment must be same as input"
	echo "----------------------------Validate number of tunables ----------------------------"
	echo ""
	if [ "${expected_env_count}" != "${actual_env_count}" ]; then
		failed=1
		display_result "${expected_behaviour}" ${test_name} ${failed}
	else
		failed=0
		display_result "${expected_behaviour}" ${test_name} ${failed}
		for env in "${expected_env[@]}"
		do
			echo "----------------------------Validate ${env}----------------------------"
			
			# Get the name of the tunable
			e_name=$(echo ${env} | awk '{print $1}' | tr -d ':')
			
			# Get the value of the tunable. Start from front, grep everything after ":"
			e_value="${env#*:}"
			
			search_string="${e_name}"
			
			# Returns the same value if ts present
			match_name=$(echo "${actual_env[@]:0}" | grep -o "${e_name}")
			match_value=$(echo "${actual_env[@]:0}" | grep -o "${e_value}")
			
			if [[ ! -z "${match_name}" && ! -z "${match_value}" ]]; then
				failed=0
			else
				failed=1
			fi
			display_result "${env}" ${test_name} ${failed}
		done
	fi
}

function validate_config_values() {
	get_layers
}

function validate_config_details() {
	actual_json="${TEST_DIR}/actual_config.json"
	
	# Generate the actual json using the listExperiment API result
	cat ${result} | jq .[0].trials[${trial}].training.config > ${actual_json}
	
	validate_config_template
	validate_config_values
}

function validate_list_exp_trials() {
	trial=$1
	
	if [ -z "${trial}" ]; then
		trial=0
	fi
	
	test_name="${FUNCNAME}"
	validate_trial_details
	validate_trial_metrics
	validate_config_details
}
