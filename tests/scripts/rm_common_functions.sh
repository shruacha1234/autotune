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

# Get actual experiment details obtained from listExperiment API and store it in actual_exp_details hashmap
function create_actual_exp_info() {
	actual_exp_details[experiment_id]=$(cat ${result} | jq .[].experiment_id)
	actual_exp_details[application_name]=$(cat ${result} | jq .[].application_name)
	actual_exp_details[objective_function]=$(cat ${result} | jq .[].objective_function)
	actual_exp_details[sla_class]=$(cat ${result} | jq .[].sla_class)
	actual_exp_details[direction]=$(cat ${result} | jq .[].direction)
}

# Get expected experiment details and store it in expected_exp_details hashmap
function create_expected_exp_info() {
	expected_exp_details[experiment_id]=$(cat ${json_file} | jq .[].id)
	expected_exp_details[application_name]="${application_name}"
	expected_exp_details[objective_function]=$(cat ${autotune_json_} | jq .spec.sla.objective_function)
	expected_exp_details[sla_class]=$(cat ${autotune_json_} | jq .spec.sla.sla_class)
	expected_exp_details[direction]=$(cat ${autotune_json_} | jq .spec.sla.direction)
}

# Perform test to validate the experiment details. Create the actual and expected experiment details hashmap and compare them 
function validate_list_exp_info() {
	exp_details=("experiment_id" "application_name" "objective_function" "sla_class" "direction")
	
	create_actual_exp_info 
	create_expected_exp_info
	
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

		expected_behaviour="Experiment details of the result must be same as input"
		display_result "${expected_behaviour}" ${test_name} ${failed}
	done

	echo "------------------------------------------------------------------------------------------" | tee -a ${LOG}
}

# Get actual trial details obtained from listExperiment API and store it in actual_trial_details hashmap
function create_actual_trial_info() {
	actual_trial_details[trial_num]=$(cat ${result} | jq .[].trials[${trial}].trial_num)
	actual_trial_details[trial_run]=$(cat ${result} | jq .[].trials[${trial}].trial_run)
	actual_trial_details[trial_measurement_time]=$(cat ${result} | jq .[].trials[${trial}].trial_measurement_time)
	actual_trial_details[deployment_name]=$(cat ${result} | jq .[].trials[${trial}].training.deployment_name)
}

# Get expected trial details and store it in expected_trial_details hashmap
function create_expected_trial_info() {
	expected_trial_details[trial_num]=$(cat ${input_json} | jq .[].trials[].trial_num)
	expected_trial_details[trial_run]=$(cat ${input_json} | jq .[].trials[].trial_run)
	expected_trial_details[trial_measurement_time]=$(cat ${input_json} | jq .[].trials[].trial_measurement_time)
	expected_trial_details[deployment_name]=$(cat ${input_json} | jq .[].trials[].training.deployment_name)
}

# Perform test to validate the trial details. Create the actual and expected trial details hashmap and compare them
function validate_trial_details() {
	trial_details=("trial_num" "trial_run" "trial_measurement_time" "deployment_name")
	declare -A expected_trial_details
	declare -A actual_trial_details
	
	create_actual_trial_info
	create_expected_trial_info
	
	for trial in "${trial_details[@]}"
	do
		echo "------------------------------ Matching ${trial} ------------------------------" | tee -a ${LOG}
		echo "" | tee -a ${LOG}
		echo "Actual ${trial}: ${actual_trial_details[$trial]}" | tee -a ${LOG}
		echo "Expected ${trial}: ${expected_trial_details[$trial]}" | tee -a ${LOG}
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

# Create the expected metric details JSON using application autotune object and layer config object
function create_expected_metric_details() {
	# Get tunables from application autotune object
	app_autotune_tunables_json="${TEST_DIR}/listExperiment_result_app_autotune_tunables.json"
	echo "$(jq '[.spec.sla.function_variables[] | {name: .name, query: .query, datasource: .datasource}] | sort_by(.name)' ${autotune_json_} | tr -d '[]')" > ${app_autotune_tunables_json}
	
	# Get tunables from layer config and combine with tunables of application autotune object
	printf '[' > ${expected_metrics_json}
	tunable_length=$(cat ${container_config} | jq '.tunables | length')
	for tunable in $(jq '.tunables | keys | .[]' ${container_config})
	do
		((tunable_length--))
		printf '\n  {' >> ${expected_metrics_json}
		printf '\n    "name": '$(cat ${container_config} | jq .tunables[${tunable}].name)',\n' >> ${expected_metrics_json}
		query="$(cat ${container_config} | jq .tunables[${tunable}].queries.datasource[].query)"
		echo '    "query": '${query}',' >> ${expected_metrics_json}
		printf '    "datasource": '$(cat ${container_config} | jq .tunables[${tunable}].queries.datasource[].name)'' >> ${expected_metrics_json}
		printf '\n  },' >> ${expected_metrics_json}
		if [ "${tunable_length}" -eq "0" ]; then
			cat ${app_autotune_tunables_json} >> ${expected_metrics_json}
		fi
	done
	printf ']' >> ${expected_metrics_json}
}

# Create the actual metrics JSON using listExperiments API result
function create_actual_metric_details() {
	# Sort the json based on metric name
	echo "$(jq '[.[].trials['${trial}'].training.metrics[] | {name: .name, query: .query, datasource: .datasource}] | sort_by(.name)' ${result})" > ${actual_metrics_json}
}

# Perform test to validate the metrics details. Create the actual and expected metric details JSON and compare them 
function validate_metric_details() {
	echo "------------------------------ Validating metric details ------------------------------" | tee -a ${LOG}
	actual_metrics_json="${TEST_DIR}/listExperiment_result_actual_metrics.json"
	expected_metrics_json="${TEST_DIR}/listExperiment_result_expected_metrics.json"
	
	create_expected_metric_details
	create_actual_metric_details
	
	# Compare the actual json and expected jsons
	compare_json "${actual_metrics_json}" "${expected_metrics_json}" "${test_name}"
	
	echo "------------------------------------------------------------------------------------------" | tee -a ${LOG}
}

# Check if any metric has blank value. If so fail the test.
function check_for_blank_values() {
	failed=0
	metrics=('"name"' '"query"' '"datasource"' '"score"' '"Error"' '"min"' '"mean"' '"mode"' '"max"' '"95.0"' '"99.0"' '"99.9"' '"99.99"' '"99.999"' '"99.9999"' '"100.0"' '"spike"')
	
	echo "test: Check metrics for blank values..." | tee -a ${LOG}
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
	
	echo "------------------------------------------------------------------------------------------" | tee -a ${LOG}
}

# Check if the percentile values for 95, 99, ... 99.9999, 100 are in ascending order(If any of the percentile value is blank then fail the test). If not fail the test.
function validate_percentile_values() {
	failed=0
	percetile=('"95.0"' '"99.0"' '"99.9"' '"99.99"' '"99.999"' '"99.9999"' '"100.0"')
	p_count=0
	
	echo ""  | tee -a ${LOG}
	echo "test: Validate percentile values..."  | tee -a ${LOG}
	
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
	
	echo "------------------------------------------------------------------------------------------" | tee -a ${LOG}
}

# Perform test to check if the mean value is less than 99 percentile. If not fail the test.
function validate_mean() {
	mean=$(echo ${trial_metrics_value['"mean"']} | tr -d '"')
	nn_percentile=$(echo ${trial_metrics_value['"99.0"']} | tr -d '"')
	
	echo ""  | tee -a ${LOG}
	echo "test: Validate Mean value..."  | tee -a ${LOG}
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

# Perform tests to validate metric values. Check if any metric has blank value, Validate the percentile values and validate mean value with respect to 99 percentile.
function vaildate_metrics_values() {
	check_for_blank_values
	validate_percentile_values
	validate_mean
}

# Perform tests to validate the trial metrics(Validate metrics details and metrics values)
function validate_trial_metrics() {
	count=0
	metric_details=("name" "query" "datasource")
	metric_length=$(cat ${result} | jq '.[].trials['${trial}'].training.metrics | length')
	
	validate_metric_details
		
	while [ ${count} -lt ${metric_length} ]
	do
		metric_name=$(cat ${result} | jq .[].trials[${trial}].training.metrics[${count}].name)
		echo "" | tee -a ${LOG} 
		echo "--------------******Validating trial_Metrics values for ${metric_name}*****-----------------" | tee -a ${LOG}
		echo "" | tee -a ${LOG} 
		# For each metric store its corresponding values and validate the metrics
		for metric in $(jq '.[].trials['${trial}'].training.metrics['${count}'] | keys | .[]' ${result})
		do
			trial_metrics_value[$metric]=$(cat ${result} | jq .[].trials[${trial}].training.metrics[${count}].${metric})
		done
		
		vaildate_metrics_values
		((count++))
	done
}

# Generate the expected config template JSON. Validate the actual config template created using listExperiment API result with respect to expected config.
function validate_config_template() {
	config_details="${TEST_DIR_}/resources/rm_result_config_info/rm_result_config_info.json"
	resources="jq .[].trials[].training.config[0].spec[].spec[].resources"
	env="jq .[].trials[].training.config[1].spec[].spec[].env"
	expected_json="${TEST_DIR}/expected_config.json"
	
	echo "" | tee -a ${LOG}
	echo "test: Validate config template for trial ${trial_num}..." | tee -a ${LOG}
	
	cpu_request=$(cat ${input_json} | ${resources}.requests.cpu)
	mem_request=$(cat ${input_json} | ${resources}.requests.memory)
	cpu_limit=$(cat ${input_json} | ${resources}.limits.cpu)
	mem_limit=$(cat ${input_json} | ${resources}.limits.memory)
	
	# Copy the template
	cp "${config_details}" "${expected_json}"
	
	# Replace the resource values with the input
	sed -i 's|"CPUREQUEST$"|'${cpu_request}'|g' ${expected_json}
	sed -i 's|"MEMREQUEST$"|'"${mem_request}"'|g' ${expected_json}
	sed -i 's|"CPULIMITS$"|'${cpu_limit}'|g' ${expected_json}
	sed -i 's|"MEMLIMIT$"|'"${mem_limit}"'|g' ${expected_json}
	
	# Get the env parameters from input json
	env_param=$(cat ${input_json} | ${env} | tr -d '{}' | tr -d '\n')
	
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
	
	echo "------------------------------------------------------------------------------------------" | tee -a ${LOG}
}

# Get the tunable value according to tunable name and check if the value is within the given range.
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

	# bc(basic calculator) returns 1 if condition is TRUE else retturns 0
 	if [[ $(bc <<< "${tunable_value} >= ${tunable_lower_bound} && ${tunable_value} <= ${tunable_upper_bound}") == 0 ]]; then
 		flag=1
	fi
	
	expected_behaviour="Application Tunable value should be within the given range"
	display_result "${expected_behaviour}" ${test_name} ${flag}
}

# Test to validate the resource values listed by listExperiments API. Check if the tunables listed are matching with the expected tunables and also tunable value is within the given range.
function validate_resource_values() {
	resources_=".[0].spec[].spec[].resources"
	container_json="${AUTOTUNE_CONFIG_JSONS_DIR}/${layer_name}.json"
	requests=$(cat ${actual_json} | jq ''${resources_}'.requests | length')
	limits=$(cat ${actual_json} | jq ''${resources_}'.limits | length')
	actual_resources_count=$(( $requests + $limits ))
	expected_resources_count=$(cat ${container_json} | jq '.tunables | length')
	
	echo "" | tee -a ${LOG}
	echo "test: Validate resource values for trial ${trial_num}..." | tee -a ${LOG}
	
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
	
	echo "------------------------------------------------------------------------------------------" | tee -a ${LOG}
}

# Test to check if the layer tunable value is within the given range
function check_env_value() {
	failed=0
	
	echo "------------------------------------------------------------------------------------------" | tee -a ${LOG}
	echo "" | tee -a ${LOG}
	echo "test: Validate env value for ${env_name}..."  | tee -a ${LOG}
	env_value=$(cat ${result} | jq .[].trials[${trial}].training.config[1].spec[].spec[].env[] | grep "${env_name}" | tr -d ''${env_name}'":X=-')

	# bc(basic calculator) returns 1 if condition is TRUE else retturns 0
	if [[ $(bc <<< "${env_value} >= ${env_lower_bound} && ${env_value} <= ${env_upper_bound}") == 0 ]]; then
 		failed=1
	fi

	expected_behaviour="Layer tunable value should be within the given range"
	display_result "${expected_behaviour}" ${test_name} ${failed}
}

# Test to validate the env. Check if the expected tunabled are listed by listExperiments API and validate the value.
function validate_env() {
	layer_config_json="${AUTOTUNE_CONFIG_JSONS_DIR}/${layer_name}.json"
	for env in $(jq '.tunables | keys | .[]' ${layer_config_json})
	do
		env_name=$(cat ${layer_config_json} | jq .tunables[${env}].name | tr -d '"')
		env_upper_bound=$(cat ${layer_config_json} | jq .tunables[${env}].upper_bound)
		env_lower_bound=$(cat ${layer_config_json} | jq .tunables[${env}].lower_bound)
		
		env_to_search=$(echo "-XX:${env_name}")
		expected_behaviour="The layer tunable ${env_name} must be present in the result"
		
		echo "" | tee -a ${LOG}
		echo "test: Validate env name ${env_name}..."  | tee -a ${LOG}
		if  grep -q "${env_name}" "${result}" ; then
			failed=0
			display_result "${expected_behaviour}" ${test_name} ${failed} 
			check_env_value
		else
			failed=1
			display_result "${expected_behaviour}" ${test_name} ${failed} 
		fi
		echo "------------------------------------------------------------------------------------------" | tee -a ${LOG}
	done
}

# Validate the tunables listed in listExperiments API for each trial
function validate_tunables() {
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

# Tests to validate config details. Validate the config template and config values(tunables)
function validate_config_details() {
	actual_json="${TEST_DIR}/actual_config.json"
	
	# Generate the config json using the listExperiment API result
	cat ${result} | jq .[0].trials[${trial}].training.config > ${actual_json}
	
	validate_config_template
	validate_tunables
}

# Perform tests to validate the experiment trial details for each trial
# input: test name
function validate_list_exp_trials() {
	test_name="${FUNCNAME}"
	
	for trial in $(jq '.[].trials | keys | .[]' ${result})
	do	
		trial_num=$(cat ${result} | jq .[].trials[${trial}].trial_num)
		input_json="${TEST_DIR_}/resources/em_input_json/petclinic_input_${trial}.json"
		validate_trial_details
		validate_trial_metrics
		validate_config_details
	done
}
