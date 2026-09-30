// SPDX-License-Identifier: Apache-2.0
package com.example.laya_mobile.laya

import android.content.res.AssetManager
import com.google.ai.edge.litert.Accelerator
import com.google.ai.edge.litert.CompiledModel

/** Raw graph outputs for one row. */
class LayaOutputs(
  /** [1, maxLen] float32; one logit per token position, read at the markers. */
  val tokenLogits: FloatArray,
  /** [1, 768] float32; pooled [CLS] embedding. */
  val pooledCls: FloatArray,
)

/**
 * LiteRT CompiledModel over the serving_default signature. Buffers are allocated once and reused,
 * so calls must be serialized by the caller.
 */
class LayaModel(assets: AssetManager, assetPath: String, numThreads: Int = 4) : AutoCloseable {
  private val model =
    CompiledModel.create(
      assets,
      assetPath,
      CompiledModel.Options(Accelerator.CPU).apply {
        cpuOptions = CompiledModel.CpuOptions(numThreads = numThreads)
      },
    )

  // Bound by name: the signature and the graph list inputs in different orders.
  private val inputs =
    listOf(INPUT_IDS, ATTENTION_MASK, QTYPE_ONEHOT).associateWith {
      model.createInputBuffer(inputName = it, signature = SIGNATURE)
    }
  private val outputs =
    listOf(TOKEN_LOGITS, POOLED_CLS).associateWith {
      model.createOutputBuffer(outputName = it, signature = SIGNATURE)
    }

  fun run(row: LayaInputs): LayaOutputs {
    require(row.inputIds.size == MAX_LEN && row.attentionMask.size == MAX_LEN) {
      "graph expects [1, $MAX_LEN] inputs, got ${row.inputIds.size}"
    }
    inputs.getValue(INPUT_IDS).writeInt(row.inputIds)
    inputs.getValue(ATTENTION_MASK).writeFloat(row.attentionMask)
    inputs.getValue(QTYPE_ONEHOT).writeFloat(row.qtypeOnehot)
    model.run(inputs, outputs, SIGNATURE)
    return LayaOutputs(
      tokenLogits = outputs.getValue(TOKEN_LOGITS).readFloat(),
      pooledCls = outputs.getValue(POOLED_CLS).readFloat(),
    )
  }

  override fun close() {
    inputs.values.forEach { it.close() }
    outputs.values.forEach { it.close() }
    model.close()
  }

  companion object {
    const val SIGNATURE = "serving_default"
    const val MAX_LEN = 256
    const val INPUT_IDS = "input_ids"
    const val ATTENTION_MASK = "attention_mask"
    const val QTYPE_ONEHOT = "qtype_onehot"
    const val TOKEN_LOGITS = "token_logits"
    const val POOLED_CLS = "pooled_cls"
  }
}
