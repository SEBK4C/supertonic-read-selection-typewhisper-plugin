# Supertonic Read Selection

Download `SupertonicReadSelectionPlugin.zip` from this release and install it from TypeWhisper's Integrations screen with Install Plugin.

## Highlights

- Optional Mac GPU inference through ONNX Runtime's Core ML execution provider.
- Sentence-aware long-text chunking with batched inference for later chunks.
- Streaming playback so audio can begin before the full selection has synthesized.
- First-utterance priority: the first sentence, or a short word-bound segment of a long first sentence, runs as its own small batch to reduce time to first audio.
