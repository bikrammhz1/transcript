#ifndef llama_bridge_h
#define llama_bridge_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Initialize llama model
 * 
 * @param modelPath Path to GGUF model file
 * @param threads Number of threads for inference
 * @param contextSize Context size in tokens
 * @return Opaque pointer to state (or nullptr on failure)
 */
void* initLlama(const char* modelPath, int threads, int contextSize);

/**
 * Generate text using initialized model
 * 
 * @param ctx State pointer from initLlama
 * @param prompt Input prompt text
 * @param maxTokens Maximum tokens to generate
 * @param temperature Sampling temperature
 * @return Generated text as C string (caller must free if allocated with new/malloc)
 */
const char* generate(void* ctx, const char* prompt, int maxTokens, float temperature);

/**
 * Release model and free memory
 * 
 * @param ctx State pointer from initLlama
 */
void releaseLlama(void* ctx);

#ifdef __cplusplus
}
#endif

#endif /* llama_bridge_h */



