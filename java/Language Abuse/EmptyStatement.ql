// Copyright 2017 Semmle Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the specific language governing
// permissions and limitations under the License.

/**
 * @name Empty statement
 * @description An empty statement hinders readability.
 * @kind problem
 * @problem.severity recommendation
 * @tags maintainability
 *       useless-code
 */

import java

from EmptyStmt empty, string action
where if exists(LoopStmt l | l.getBody() = empty) then (
    action = "turned into '{}'"
  ) else (
    action = "deleted"
  )
select empty, "This empty statement should be " + action + "."