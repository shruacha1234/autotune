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
##### Constants for RM tests #####

space=" "
# Breif description about the experiment manager tests
declare -A rm_api_test_description
rm_api_test_description=([validate_list_exp_query]="Deploy autotune and required dependencies, query the list experiment API with different combinations and validate the result"
[validate_list_exp_result]="Deploy autotune and required dependencies, query the list experiment API and validate the result")

validate_list_exp_query_testcases=("invalid-exp-id"
"empty-exp-id"
"no-exp-id"
"null-exp-id"
"invalid-trial-number"
"empty-trial-number"
"no-trial-number"
"null-trial-number"
"no-exp-id-trial-number"
"valid-exp-id"
"valid-exp-id-trial-number")

