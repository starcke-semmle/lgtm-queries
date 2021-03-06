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
 * @name Unreachable catch clause
 * @description An unreachable 'catch' clause may indicate a mistake in exception handling or may
 *              be unnecessary.
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags reliability
 *       correctness
 *       exceptions
 *       external/cwe/cwe-561
 */

import java

/**
 * Exceptions of type `rt` thrown from within statement `s` are caught by an inner try block
 * and are therefore not propagated to the outer try block `t`.
 */
private
predicate caughtInside(TryStmt t, Stmt s, RefType rt) {
  exists(TryStmt innerTry | innerTry.getParent+() = t.getBlock() |
    s.getParent+() = innerTry.getBlock() and
    caughtType(innerTry, _).hasSubtype*(rt)
  )
}

/**
 * Returns an exception type thrown from within the try block of `t`
 * that is relevant to the catch clauses of `t` (i.e. not already
 * caught by an inner try-catch).
 */
private
RefType getAThrownExceptionType(TryStmt t) {
  exists(Method m, Exception e |
    m = t.getAResourceDecl().getAVariable().getType().(RefType).getAMethod() and
    m.hasName("close") and
    m.hasNoParameters() and
    m.getAnException() = e and
    result = e.getType()
  ) or
  exists(Call call, Exception e |
    t.getBlock() = call.getEnclosingStmt().getParent*() or
    t.getAResourceDecl() = call.getEnclosingStmt()
    |
    call.getCallee().getAnException() = e and
    not caughtInside(t, call.getEnclosingStmt(), e.getType()) and
    result = e.getType()
  ) or
  exists(ThrowStmt ts |
    t.getBlock() = ts.getParent*() and
    not caughtInside(t, ts, ts.getExpr().getType()) and
    result = ts.getExpr().getType()
  )
}

private
RefType caughtType(TryStmt try, int index) {
  exists(CatchClause cc | cc = try.getCatchClause(index) |
    if cc.isMultiCatch()
    then result = cc.getVariable().getTypeAccess().(UnionTypeAccess).getAnAlternative().getType()
    else result = cc.getVariable().getType()
  )
}

private
predicate maybeUnchecked(RefType t) {
     t.getASupertype*().hasQualifiedName("java.lang", "RuntimeException")
  or t.getASupertype*().hasQualifiedName("java.lang", "Error")
  or t.hasQualifiedName("java.lang", "Exception")
  or t.hasQualifiedName("java.lang", "Throwable")
}

predicate overlappingExceptions(RefType e1, RefType e2) {
  exists(RefType throwable | throwable.hasQualifiedName("java.lang", "Throwable") |
    throwable.hasSubtype*(e1) and
    throwable.hasSubtype*(e2) and
    e1.getASubtype*() = e2.getASubtype*()
  )
}

from TryStmt try, int first, int second, RefType masking, RefType masked, string multiCatchMsg
where masking = caughtType(try, first)
  and masking.getASupertype+() = masked
  and masked = caughtType(try, second)
  and forall(RefType thrownType |
        thrownType = getAThrownExceptionType(try) and
        // If there's any overlap in the types, this catch block may be relevant.
        overlappingExceptions(thrownType, masked)
      | exists(RefType priorCaughtType, int priorIdx |
          priorIdx < second and
          priorCaughtType = caughtType(try, priorIdx) and
          thrownType.hasSupertype*(priorCaughtType)
        )
      )
  and not maybeUnchecked(masked)
  and if try.getCatchClause(second).isMultiCatch()
      then multiCatchMsg = " for type " + masked.getName()
      else multiCatchMsg = ""
select
  try.getCatchClause(second),
  "This catch-clause is unreachable" + multiCatchMsg + "; it is masked $@.",
  try.getCatchClause(first),
  "here for exceptions of type '" + masking.getName() + "'"
