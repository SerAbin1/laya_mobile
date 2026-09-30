// SPDX-License-Identifier: Apache-2.0
package com.example.laya_mobile.laya

/** Fixed-shape graph inputs for one question row, plus the [MASK] positions to gather. */
class LayaInputs(
  /** [1, maxLen] int32; real IDs followed by PAD. */
  val inputIds: IntArray,
  /** [1, maxLen] float32; 1.0 for real tokens, 0.0 for PAD. */
  val attentionMask: FloatArray,
  /** [1, 3] float32; choice/score/noul one-hot. */
  val qtypeOnehot: FloatArray,
  /** Index of every [MASK] in inputIds, in option order. */
  val markers: IntArray,
  /** Source question; the decoder needs its type and option labels. */
  val question: LayaQuestion,
) {
  companion object {
    const val QTYPE_COUNT = 3

    /** Pads an unpadded sequence to maxLen and derives mask and qtype channels. */
    fun from(sequence: LayaSequence, maxLen: Int = 256): LayaInputs {
      val ids = sequence.sequenceIds
      require(ids.size <= maxLen) { "sequence length ${ids.size} exceeds maxLen=$maxLen" }
      val inputIds = IntArray(maxLen) { if (it < ids.size) ids[it] else LayaPromptBuilder.PAD }
      val attentionMask = FloatArray(maxLen) { if (it < ids.size) 1f else 0f }
      val qtypeOnehot = FloatArray(QTYPE_COUNT).also { it[sequence.question.qtype] = 1f }
      val markers = sequence.markerPositions.copyOf()
      for (marker in markers) {
        check(inputIds[marker] == LayaPromptBuilder.MASK) {
          "marker $marker points at ${inputIds[marker]}, not MASK"
        }
      }
      return LayaInputs(inputIds, attentionMask, qtypeOnehot, markers, sequence.question)
    }
  }
}

/** Builds padded inputs for a choice question: one [MASK] per option, in list order. */
fun LayaPromptBuilder.buildChoiceInputs(
  questionText: String,
  options: List<String>,
  stateText: String,
): LayaInputs {
  val question =
    mapOf("type" to "choice", "instructions" to questionText, "criteria" to options)
  return LayaInputs.from(build(stateText, question), maxLen)
}
