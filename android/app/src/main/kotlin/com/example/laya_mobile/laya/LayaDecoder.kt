// SPDX-License-Identifier: Apache-2.0
package com.example.laya_mobile.laya

import kotlin.math.exp

/** Calibrated answer for one question; options/probabilities share marker order. */
class LayaAnswer(
  val qtype: String,
  val options: List<String>,
  val rawLogits: DoubleArray,
  val temperature: Double,
  val probabilities: DoubleArray,
) {
  val bestIndex: Int = probabilities.indices.maxBy { probabilities[it] }
  val best: String
    get() = options[bestIndex]
  val confidence: Double
    get() = probabilities[bestIndex]

  fun toJson(): String =
    LayaJson.stringify(
      linkedMapOf(
        "type" to qtype,
        "answer" to best,
        "confidence" to confidence,
        "probabilities" to options.indices.associate { options[it] to probabilities[it] },
        "temperature" to temperature,
        "raw_logits" to rawLogits.toList(),
      )
    )
}

/** Gathers marker logits, divides by the calibrated temperature, and softmaxes. */
class LayaDecoder(private val calibration: LayaCalibration) {
  fun decode(inputs: LayaInputs, outputs: LayaOutputs): LayaAnswer {
    val question = inputs.question
    val labels = optionLabels(question)
    require(labels.size == inputs.markers.size) {
      "${labels.size} options but ${inputs.markers.size} markers"
    }
    val raw = DoubleArray(inputs.markers.size) { outputs.tokenLogits[inputs.markers[it]].toDouble() }
    val temperature = calibration.temperature(question.type, raw.size)
    return LayaAnswer(
      question.type,
      labels,
      raw,
      temperature,
      softmax(DoubleArray(raw.size) { raw[it] / temperature }),
    )
  }

  companion object {
    /** Subtracts the max before exp so large logits cannot overflow. */
    fun softmax(logits: DoubleArray): DoubleArray {
      val max = logits.max()
      val exps = DoubleArray(logits.size) { exp(logits[it] - max) }
      val sum = exps.sum()
      return DoubleArray(exps.size) { exps[it] / sum }
    }

    /** Choice answers use the bare label, not the "label: description" prompt text. */
    fun optionLabels(question: LayaQuestion): List<String> =
      when (question.type) {
        "choice" -> LayaJson.asObject(question.criteria).keys.toList()
        "noul" -> listOf("false", "true")
        else -> LayaPromptBuilder.renderOptions(question)
      }
  }
}
