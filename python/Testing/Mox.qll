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

import python

/** Whether `mox` or `.StubOutWithMock()` is used in thin module `m`.
 */
predicate useOfMoxInModule(Module m) {
    exists(ModuleObject mox |
        mox.getName() = "mox" or mox.getName() = "mox3.mox" |
        exists(ControlFlowNode use | 
            use.refersTo(mox) and
            use.getScope().getEnclosingModule() = m
        )
    )
    or
    exists(Call call|
        call.getFunc().(Attribute).getName() = "StubOutWithMock" and
        call.getEnclosingModule() = m
    )
}
