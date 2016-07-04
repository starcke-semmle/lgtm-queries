// Copyright 2016 Semmle Ltd.
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
 * @name Special method has incorrect signature
 * @description Special method has incorrect signature
 * @kind problem
 * @problem.severity error
 */

import python


predicate is_unary_op(string name) {
  name = "__del__" or
  name = "__repr__" or
  name = "__str__" or
  name = "__hash__" or
  name = "__bool__" or
  name = "__nonzero__" or
  name = "__unicode__" or
  name = "__len__" or
  name = "__iter__" or
  name = "__reversed__" or
  name = "__neg__" or
  name = "__pos__" or
  name = "__abs__" or
  name = "__invert__" or
  name = "__complex__" or
  name = "__int__" or
  name = "__float__" or
  name = "__long__" or
  name = "__oct__" or
  name = "__hex__" or
  name = "__index__" or
  name = "__enter__"
}

predicate is_binary_op(string name) {
   name = "__lt__" or
  name = "__le__" or
  name = "__eq__" or
  name = "__ne__" or
  name = "__gt__" or
  name = "__ge__" or
  name = "__cmp__" or
  name = "__rcmp__" or
  name = "__getattr___" or
  name = "__getattribute___" or
  name = "__delattr__" or
  name = "__delete__" or
  name = "__instancecheck__" or
  name = "__subclasscheck__" or
  name = "__getitem__" or
  name = "__delitem__" or
  name = "__contains__" or
  name = "__add__" or
  name = "__sub__" or
  name = "__mul__" or
  name = "__floordiv__" or
  name = "__div__" or
  name = "__truediv__" or
  name = "__mod__" or
  name = "__divmod__" or
  name = "__lshift__" or
  name = "__rshift__" or
  name = "__and__" or
  name = "__xor__" or
  name = "__or__" or
  name = "__radd__" or
  name = "__rsub__" or
  name = "__rmul__" or
  name = "__rfloordiv__" or
  name = "__rdiv__" or
  name = "__rtruediv__" or
  name = "__rmod__" or
  name = "__rdivmod__" or
  name = "__rpow__" or
  name = "__rlshift__" or
  name = "__rrshift__" or
  name = "__rand__" or
  name = "__rxor__" or
  name = "__ror__" or
  name = "__iadd__" or
  name = "__isub__" or
  name = "__imul__" or
  name = "__ifloordiv__" or
  name = "__idiv__" or
  name = "__itruediv__" or
  name = "__imod__" or
  name = "__idivmod__" or
  name = "__ipow__" or
  name = "__ilshift__" or
  name = "__irshift__" or
  name = "__iand__" or
  name = "__ixor__" or
  name = "__ior__" or
  name = "__coerce__"
}

predicate is_ternary_op(string name) {
  name = "__setattr__" or
  name = "__set__" or
   name = "__setitem__" or
  name = "__getslice__" or
  name = "__delslice__"
}

predicate is_quad_op(string name) {
    name = "__setslice__" or name = "__exit__"
}

int non_default_pcount(Function f) {
    exists(CallableExpr ce | ce = f.getDefinition() |
        result = count(f.getAnArg()) - count(ce.getArgs().getADefault())
    )
}

int pcount(Function f) {
    result = count(f.getAnArg())
}

int argument_count(PyFunctionObject f, string name, ClassObject cls) {
    cls.declaredAttribute(name) = f and
    (
        is_unary_op(name) and result = 1
        or
        is_binary_op(name) and result = 2
        or
        is_ternary_op(name) and result = 3
        or
        is_quad_op(name) and result = 4
    )
}

predicate incorrect_special_method_defn(PyFunctionObject func, string message, boolean show_counts, string name, ClassObject owner) {
   exists(Function f, int required, int actual, int actual_non_default |
          f = func.getFunction() and
          not exists(f.getVararg()) and
          required = argument_count(func, name, owner) and
          actual = pcount(f) and
          actual_non_default = non_default_pcount(f) |
          /* actual_non_default <= actual */
          if required > actual then
              (message = "Too few parameters" and show_counts = true)
          else if required < actual_non_default then
              (message = "Too many parameters" and show_counts = true)
          else if actual_non_default < required then
              (message = (required -actual_non_default) +  " default values(s) will never be used" and show_counts = false)
          else
              none()
   )
}

predicate incorrect_pow(FunctionObject func, string message, boolean show_counts, ClassObject owner) {
    owner.declaredAttribute("__pow__") = func and
    exists(Function f | f = func.getFunction() |
       pcount(f) < 2 and message = "Too few parameters" and show_counts = true
       or
       non_default_pcount(f) > 3 and message = "Too many parameters" and show_counts = true
       or
       non_default_pcount(f) < 2 and message = (2 - non_default_pcount(f)) + " default value(s) will never be used" and show_counts = false
       or
       non_default_pcount(f) = 3 and message = "Third parameter to __pow__ should have a default value" and show_counts = false
     )
}

predicate incorrect_get(FunctionObject func, string message, boolean show_counts, ClassObject owner) {
    owner.declaredAttribute("__get__") = func and
    exists(Function f | f = func.getFunction() |
       pcount(f) < 3 and message = "Too few parameters" and show_counts = true
       or
       non_default_pcount(f) > 3 and message = "Too many parameters" and show_counts = true
       or
       non_default_pcount(f) < 2 and message = (2 - non_default_pcount(f)) + " default value(s) will never be used" and show_counts = false
     )
}

string should_have_parameters(PyFunctionObject f, string name, ClassObject owner) {
    exists(int i | i = argument_count(f, name, owner) | 
        result = i.toString()
    )
    or 
    owner.declaredAttribute(name) = f and (name = "__get__" or name = "__pow__") and result = "2 or 3"
}

string has_parameters(PyFunctionObject f) {
    exists(int i | i = pcount(f.getFunction()) |
        i = 0 and result = "no parameters"
        or
        i = 1 and result = "1 parameter"
        or
        i > 1 and result = i.toString() + " parameters"
    )
}

from PyFunctionObject f, string message, string sizes, boolean show_counts, string name, ClassObject owner
where 
  (
    incorrect_special_method_defn(f, message, show_counts, name, owner)
    or 
    incorrect_pow(f, message, show_counts, owner) and name = "__pow__"
    or 
    incorrect_get(f, message, show_counts, owner) and name = "__get__"
  ) 
  and 
  (
    show_counts = false and sizes = "" or
    show_counts = true and sizes = ", which has " + has_parameters(f) + ", but should have " + should_have_parameters(f, name, owner)
  )
select f, message + " for special method " + name + sizes + ", in class $@.", owner, owner.getName()
