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
 * @name Inefficient use of key set iterator
 * @description Iterating through the values of a map using the key set is inefficient.
 * @kind problem
 * @problem.severity recommendation
 * @tags efficiency
 *       maintainability
 */
import java

/** A local variable that is initialized using a key-set iterator. */
class KeySetIterator extends LocalVariableDecl {
   KeySetIterator() {
     exists(LocalVariableDeclExpr lvde, MethodAccess init |
       lvde.getVariable() = this and
       lvde.getInit() = init and
       init.getMethod().hasName("iterator") and
       init.getQualifier().(MethodAccess).getMethod().hasName("keySet")
     )
   }

   LocalVariableDecl getBase() {
     exists(LocalVariableDeclExpr lvde, MethodAccess init |
       lvde.getVariable() = this and
       lvde.getInit() = init and
       init.getQualifier().(MethodAccess).getQualifier().(VarAccess).getVariable() = result
     )
   }
}

predicate isKeyNext(Expr e, KeySetIterator it) {
  exists(MethodAccess ma | ma = e |
    ma.getMethod().hasName("next") and
    ma.getQualifier().(VarAccess).getVariable() = it
  ) or
  isKeyNext(e.(CastExpr).getExpr(), it)
}

class Key extends LocalVariableDecl {
  Key() {
    exists(LocalVariableDeclExpr lvde, KeySetIterator it |
      lvde.getVariable() = this and
      isKeyNext(lvde.getInit(), it)
    )
  }

  KeySetIterator getBase() {
    exists(LocalVariableDeclExpr lvde |
      lvde.getVariable() = this and
      isKeyNext(lvde.getInit(), result)
    )
  } 
}

from MethodAccess ma, Method get
where ma.getMethod() = get and 
      get.hasName("get") and
      ma.getAnArgument().(VarAccess).getVariable().(Key).getBase().getBase()
        = ma.getQualifier().(VarAccess).getVariable()
select ma, "Inefficient use of key set iterator instead of entry set iterator."
