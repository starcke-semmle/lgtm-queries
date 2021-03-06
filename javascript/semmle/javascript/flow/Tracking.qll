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
 * Provides classes for performing customized data flow tracking.
 *
 * The classes in this module allow restricting the data flow analysis
 * to a particular set of source or sink nodes, and providing extra
 * edges along which flow should be propagated.
 *
 * NOTE: The API of this library is not stable yet and may change in
 *       the future.
 */

import javascript

/**
 * A data flow tracking configuration.
 *
 * Each use of the data flow tracking library must define its own unique extension
 * of this abstract class. A configuration defines a set of relevant sources
 * (`isSource`) and sinks (`isSink`), and may additionally
 * define additional edges beyond the standard data flow edges (`isAdditionalFlowStep`)
 * and prohibit intermediate flow nodes (`isBarrier`).
 */
abstract class FlowTrackingConfiguration extends string {
  bindingset[this]
  FlowTrackingConfiguration() { any() }

  /**
   * Holds if `source` is a relevant data flow source.
   *
   * The smaller this predicate is, the faster `flowsFrom()` will converge.
   */
  abstract predicate isSource(DataFlowNode source);

  /**
   * Holds if `sink` is a relevant data flow sink.
   *
   * The smaller this predicate is, the faster `flowsFrom()` will converge.
   */
  abstract predicate isSink(DataFlowNode sink);

  /**
   * Holds if `source -> sink` should be considered as a flow edge
   * in addition to standard data flow edges.
   */
  predicate isAdditionalFlowStep(DataFlowNode src, DataFlowNode trg) { none() }

  /**
   * Holds if the intermediate flow node `node` is prohibited.
   *
   * Note that flow through standard data flow edges cannot be prohibited.
   */
  predicate isBarrier(DataFlowNode node) { none() }

  /**
   * Holds if `source` flows to `sink`.
   *
   * The analysis searches *forwards* from the source to the sink.
   *
   * **Note**: use `flowsFrom(sink, source)` instead if the set of sinks is
   * expected to be smaller than the set of sources.
   */
  predicate flowsTo(DataFlowNode source, DataFlowNode sink) {
    flowsTo(source, sink, this) and
    isSink(sink)
  }

  /**
   * Holds if `source` flows to `sink`.
   *
   * The analysis searches *backwards* from the sink to the source.
   *
   * **Note**: use `flowsTo(source, sink)` instead if the set of sources is
   * expected to be smaller than the set of sinks.
   */
  predicate flowsFrom(DataFlowNode sink, DataFlowNode source) {
    flowsFrom(source, sink, this) and
    isSource(source)
  }
}

/**
 * Holds if `source` can flow to `sink` under the given `configuration`
 * in zero or more steps.
 */
private predicate flowsTo(DataFlowNode source, DataFlowNode sink, FlowTrackingConfiguration configuration) {
  (
    // Base case
    sink = source and
    configuration.isSource(source)
    or
    // Local flow
    exists (DataFlowNode mid |
      flowsTo(source, mid, configuration) and
      mid = sink.localFlowPred()
    )
    or
    // Extra flow
    exists(DataFlowNode mid |
      flowsTo(source, mid, configuration) and
      configuration.isAdditionalFlowStep(mid, sink)
    )
  )
  and
  not configuration.isBarrier(sink)
}

/**
 * Holds if `source` can flow to `sink` under the given `configuration`
 * in zero or more steps.
 *
 * Unlike `flowsTo`, this predicate searches backwards from the sink
 * to the source.
 */
private predicate flowsFrom(DataFlowNode source, DataFlowNode sink, FlowTrackingConfiguration configuration) {
  (
    // Base case
    sink = source and
    configuration.isSink(sink)
    or
    // Local flow
    exists (DataFlowNode mid |
      flowsFrom(mid, sink, configuration) and
      source = mid.localFlowPred()
    )
    or
    // Extra flow
    exists (DataFlowNode mid |
      flowsFrom(mid, sink, configuration) and
      configuration.isAdditionalFlowStep(source, mid)
    )
  )
  and
  not configuration.isBarrier(source)
}

/**
 * Provides classes for modelling taint propagation.
 */
module TaintTracking {
  /**
   * A data flow tracking configuration that considers taint propagation through
   * objects, arrays, promises and strings in addition to standard data flow.
   *
   * If a different set of flow edges is desired, extend this class and override
   * `isAdditionalTaintStep`.
   */
  abstract class Configuration extends FlowTrackingConfiguration {
    bindingset[this]
    Configuration() { any() }

    /**
     * Holds if `source` is a relevant taint source.
     *
     * The smaller this predicate is, the faster `hasFlow()` will converge.
     */
    // overridden to provide taint-tracking specific qldoc
    abstract override predicate isSource(DataFlowNode source);

    /**
     * Holds if `sink` is a relevant taint sink.
     *
     * The smaller this predicate is, the faster `hasFlow()` will converge.
     */
    // overridden to provide taint-tracking specific qldoc
    abstract override predicate isSink(DataFlowNode sink);

    /** Holds if the intermediate node `node` is a taint sanitizer. */
    predicate isSanitizer(DataFlowNode node) {
      sanitizedByGuard(this, node)
    }

    final
    override predicate isBarrier(DataFlowNode node) { isSanitizer(node) }

    /**
     * Holds if the additional taint propagation step from `pred` to `succ`
     * must be taken into account in the analysis.
     */
    predicate isAdditionalTaintStep(DataFlowNode pred, DataFlowNode succ) {
      pred = succ.(FlowTarget).getATaintSource()
    }

    final
    override predicate isAdditionalFlowStep(DataFlowNode pred, DataFlowNode succ) {
      isAdditionalTaintStep(pred, succ)
    }
  }

  /**
   * Holds if variable use `u` is sanitized for the purposes of taint-tracking
   * configuration `cfg`.
   */
  private predicate sanitizedByGuard(Configuration cfg, VarUse u) {
    exists (SsaVariable v | u = v.getAUse() |
      // either `v` is a refined variable where the guard performs
      // sanitization
      exists (SsaRefinementNode ref | v = ref.getVariable() |
        guardSanitizes(cfg, ref.getGuard(), _)
      )
      or
      // or there is a non-refining guard that dominates this use
      exists (ConditionGuardNode guard |
        guardSanitizes(cfg, guard, v) and guard.dominates(u.getBasicBlock())
      )
    )
  }

  /**
   * Holds if `guard` is sanitizes `v` for the purposes of taint-tracking
   * configuration `cfg`.
   */
  private predicate guardSanitizes(Configuration cfg,
                                   ConditionGuardNode guard, SsaVariable v) {
    exists (SanitizingGuard sanitizer | sanitizer = guard.getTest() |
      sanitizer.sanitizes(cfg, guard.getOutcome(), v)
    )
  }

  /**
   * An expression that can act as a sanitizer for a variable when appearing
   * in a condition.
   */
  abstract class SanitizingGuard extends Expr {
    /**
     * Holds if this expression sanitizes variable `v` for the purposes of taint-tracking
     * configuration `cfg`, provided it evaluates to `outcome`.
     */
    abstract predicate sanitizes(Configuration cfg, boolean outcome, SsaVariable v);
  }

  /**
   * A taint propagating data flow edge, represented by its target node.
   */
  abstract class FlowTarget extends DataFlowNode {
    /** Gets another data flow node from which taint is propagated to this node. */
    abstract DataFlowNode getATaintSource();
  }

  /**
   * A taint propagating data flow edge through object or array elements and
   * promises.
   */
  private class DefaultFlowTarget extends FlowTarget {
    DefaultFlowTarget() {
      this instanceof Expr
    }

    override DataFlowNode getATaintSource() {
      // iterating over a tainted iterator taints the loop variable
      exists (EnhancedForLoop efl | result = efl.getIterationDomain() |
        this = efl.getAnIterationVariable().getAnAccess()
      )
      or
      // arrays with tainted elements and objects with tainted properties are tainted
      this.(ArrayExpr).getAnElement() = result or
      exists (Property prop | this.(ObjectExpr).getAProperty() = prop |
        prop.isComputed() and result = prop.getNameExpr() or
        result = prop.getInit()
      )
      or
      // reading from a tainted object or with a tainted index yields a tainted result
      this.(IndexExpr).getAChildExpr() = result or
      this.(DotExpr).getBase() = result
      or
      // awaiting a tainted expression gives a tainted result
      this.(AwaitExpr).getOperand() = result
      or
      // comparing a tainted expression against a constant gives a tainted result
      this.(Comparison).hasOperands(result, any(Expr e | exists(e.getStringValue())))
    }
  }

  /**
   * A taint propagating data flow edge arising from string append and other string
   * operations defined in the standard library.
   *
   * Note that since we cannot easily distinguish string append from addition, we consider
   * any `+` operation to propagate taint.
   */
  private class StringManipulationFlowTarget extends FlowTarget {
    StringManipulationFlowTarget() {
      this instanceof Expr
    }

    override DataFlowNode getATaintSource() {
      // addition propagates taint
      this.(AddExpr).getAnOperand() = result or
      this.(AssignAddExpr).getAChildExpr() = result
      or
      // templating propagates taint
      this.(TemplateLiteral).getAnElement() = result
      or
      // other string operations that propagate taint
      exists (string name | name = this.(MethodCallExpr).getMethodName() |
        result = this.(MethodCallExpr).getReceiver() and
        (name = "concat" or name = "match" or name = "replace" or name = "slice" or
         name = "split" or name = "substr" or name = "substring" or
         name = "toLocaleLowerCase" or name = "toLocaleUpperCase" or
         name = "toLowerCase" or name = "toString" or name = "toUpperCase" or
         name = "trim" or name = "valueOf")
        or
        exists (int i | result = this.(MethodCallExpr).getArgument(i) |
          name = "concat" or
          name = "replace" and i = 1
        )
      )
      or
      // standard library constructors that propagate taint: `RegExp` and `String`
      exists (InvokeExpr invk, GlobalVarAccess gv |
        invk = this and gv = invk.getCallee() and result = invk.getArgument(0) |
        gv.getName() = "RegExp" or gv.getName() = "String"
      )
      or
      // regular expression operations that propagate taint
      exists (MethodCallExpr mce | mce = this |
        // RegExp.prototype.exec: from first argument to call
        mce.getReceiver().(DataFlowNode).getALocalSource() instanceof RegExpLiteral and
        mce.getMethodName() = "exec" and
        result = mce.getArgument(0)
      )
      or
      // `(encode|decode)URI(Component)?` propagate taint
      exists (CallExpr c, string name |
        c = this and accessesGlobal(c.getCallee(), name) and result = c.getArgument(0) |
        name = "encodeURI" or name = "decodeURI" or
        name = "encodeURIComponent" or name = "decodeURIComponent"
      )
    }
  }

  /**
   * A taint propagating data flow edge arising from JSON parsing or unparsing.
   */
  private class JsonManipulationFlowTarget extends FlowTarget, @callexpr {
    JsonManipulationFlowTarget() {
      exists (MethodCallExpr mce, string methodName |
        mce = this and methodName = mce.getMethodName() |
        accessesGlobal(mce.getReceiver(), "JSON") and
        (methodName = "parse" or methodName = "stringify")
      )
    }

    override DataFlowNode getATaintSource() {
      result = this.(CallExpr).getArgument(0)
    }
  }
}