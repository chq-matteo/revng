#pragma once

//
// This file is distributed under the MIT License. See LICENSE.md for details.
//

#include <string>

#include "llvm/ADT/DenseMap.h"
#include "llvm/Pass.h"

#include "revng/BasicAnalyses/GeneratedCodeBasicInfo.h"
#include "revng/FunctionCallIdentification/FunctionCallIdentification.h"
#include "revng/StackAnalysis/FunctionsSummary.h"
#include "revng/Support/OpaqueFunctionsPool.h"

namespace StackAnalysis {

extern const std::set<llvm::GlobalVariable *> EmptyCSVSet;

template<bool AnalyzeABI>
class StackAnalysis : public llvm::ModulePass {
  friend class FunctionBoundariesDetectionPass;

public:
  static char ID;

public:
  StackAnalysis() : llvm::ModulePass(ID) {}

  void getAnalysisUsage(llvm::AnalysisUsage &AU) const override {
    AU.setPreservesAll();
    AU.addRequired<GeneratedCodeBasicInfoWrapperPass>();
  }

  bool runOnModule(llvm::Module &M) override;

  const std::set<llvm::GlobalVariable *> &
  getClobbered(llvm::BasicBlock *Function) const {
    auto It = GrandResult.Functions.find(Function);
    if (It == GrandResult.Functions.end())
      return EmptyCSVSet;
    else
      return It->second.ClobberedRegisters;
  }

  void serialize(std::ostream &Output) { Output << TextRepresentation; }

  void serializeMetadata(llvm::Function &F);

public:
  FunctionsSummary GrandResult;
  std::string TextRepresentation;
};

template<>
char StackAnalysis<true>::ID;

template<>
char StackAnalysis<false>::ID;

extern template void StackAnalysis<true>::serializeMetadata(llvm::Function &F);
extern template void StackAnalysis<false>::serializeMetadata(llvm::Function &F);

enum class FunctionKind { Regular, NoReturn, Fake };

struct Func {
  Func(FunctionKind FuncTy,
       llvm::Function *FakeFunc,
       std::set<llvm::GlobalVariable *> ClobberedRegisters = {}) :
    FuncTy(FuncTy),
    FakeFunc(FakeFunc),
    ClobberedRegisters(ClobberedRegisters) {}

  FunctionKind FuncTy;
  llvm::Function *FakeFunc;
  std::set<llvm::GlobalVariable *> ClobberedRegisters;
};

class FunctionProperties {
private:
  /// \brief Map from CFEP to its function description
  llvm::DenseMap<llvm::BasicBlock *, Func> Bucket;

public:
  FunctionProperties() {}

  FunctionKind getFunctionType(llvm::BasicBlock *BB) {
    return FunctionKind::Regular;
  }

  llvm::Function *getFakeFunction(llvm::BasicBlock *BB) {
    auto It = Bucket.find(BB);
    if (It != Bucket.end())
      return It->second.FakeFunc;
    return nullptr;
  }

  bool isFakeFunction(llvm::Function *F) const { return false; }

  const auto &getRegistersClobbered(llvm::BasicBlock *BB) {
    auto It = Bucket.find(BB);
    if (It != Bucket.end())
      return It->second.ClobberedRegisters;
    return EmptyCSVSet;
  }

  void registerFunc(llvm::BasicBlock *BB, Func F) { Bucket.try_emplace(BB, F); }
};

template<class FunctionOracle>
class CFEPAnalyzer {
  llvm::Module &M;
  llvm::LLVMContext &Context;
  const GeneratedCodeBasicInfo &GCBI;
  FunctionOracle &Oracle;
  OpaqueFunctionsPool<llvm::StringRef> OFPRegistersClobbered;
  OpaqueFunctionsPool<llvm::StringRef> OFPIndirectBranchInfo;
  OpaqueFunctionsPool<llvm::StringRef> OFPHooksFunctionCall;

public:
  CFEPAnalyzer(llvm::Module &M,
               const GeneratedCodeBasicInfo &GCBI,
               FunctionOracle &Oracle) :
    M(M),
    Context(M.getContext()),
    GCBI(GCBI),
    Oracle(Oracle),
    OFPRegistersClobbered(&M, false),
    OFPIndirectBranchInfo(&M, false),
    OFPHooksFunctionCall(&M, false) {}

public:
  Func analyze(llvm::BasicBlock *BB);

private:
  llvm::Function *createDisposableFunction(llvm::BasicBlock *BB);
  void throwDisposableFunction(llvm::Function *F);
  void integrateFunctionCallee(llvm::BasicBlock *BB);
};

} // namespace StackAnalysis
