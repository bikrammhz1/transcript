// llama_ios.cpp - Native llama.cpp integration for iOS
// This file provides C++ bridge functions for Swift to call llama.cpp APIs

// Check if llama.cpp headers are available
#ifdef __has_include
    #if __has_include("llama.h")
        #define LLAMA_CPP_AVAILABLE 1
        #include "llama.h"
    #else
        #define LLAMA_CPP_AVAILABLE 0
        #warning "llama.h not found - llama.cpp not integrated yet. Run ./ios/build_llama.sh first."
    #endif
#else
    // Fallback for older compilers
    #ifdef LLAMA_CPP_INTEGRATED
        #define LLAMA_CPP_AVAILABLE 1
        #include "llama.h"
    #else
        #define LLAMA_CPP_AVAILABLE 0
    #endif
#endif

#include <string>
#include <vector>
#include <cstring>
#include <Foundation/Foundation.h>

extern "C" {

// State structure to hold model and context
#if LLAMA_CPP_AVAILABLE
struct llama_state_t {
    llama_model* model;
    llama_context* context;
    const llama_vocab* vocab;
    llama_sampler* sampler;

    llama_state_t() : model(nullptr), context(nullptr), vocab(nullptr), sampler(nullptr) {}
};
#endif

/**
 * Initialize llama model (iOS)
 */
void* initLlama(const char* modelPath, int threads, int contextSize) {
    NSLog(@"🚀 [llama_ios.cpp] initLlama() called");

#if !LLAMA_CPP_AVAILABLE
    NSLog(@"❌ [llama_ios.cpp] FAILED: llama.cpp not integrated yet!");
    return nullptr;
#endif

    if (!modelPath) {
        NSLog(@"❌ [llama_ios.cpp] FAILED: Model path is null");
        return nullptr;
    }

    NSLog(@"📋 [llama_ios.cpp] Init parameters:");
    NSLog(@"   - Model path: %s", modelPath);
    NSLog(@"   - Threads: %d", threads);
    NSLog(@"   - Context size: %d", contextSize);

    // Validate parameters
    if (threads < 1 || threads > 8) {
        NSLog(@"⚠️ [llama_ios.cpp] Invalid thread count, using 2");
        threads = 2;
    }
    if (contextSize < 512 || contextSize > 4096) {
        NSLog(@"⚠️ [llama_ios.cpp] Invalid context size, using 2048");
        contextSize = 2048;
    }

#if LLAMA_CPP_AVAILABLE
    // Initialize llama backend
    llama_backend_init();

    // Step 1: Load model from GGUF file
    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 999; // Use Metal GPU acceleration

    NSLog(@"⏳ [llama_ios.cpp] Loading model from file...");
    llama_model* model = llama_model_load_from_file(modelPath, model_params);

    if (!model) {
        NSLog(@"❌ [llama_ios.cpp] FAILED: Could not load model from %s", modelPath);
        return nullptr;
    }

    NSLog(@"✅ [llama_ios.cpp] Model loaded successfully");

    // Get vocab from model
    const llama_vocab* vocab = llama_model_get_vocab(model);

    // Step 2: Create context for inference
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = contextSize;
    ctx_params.n_threads = threads;
    ctx_params.n_threads_batch = threads;

    NSLog(@"⏳ [llama_ios.cpp] Creating context...");
    llama_context* ctx = llama_init_from_model(model, ctx_params);

    if (!ctx) {
        NSLog(@"❌ [llama_ios.cpp] FAILED: Could not create context");
        llama_model_free(model);
        return nullptr;
    }

    NSLog(@"✅ [llama_ios.cpp] Context created successfully");

    // Step 3: Create sampler chain
    llama_sampler_chain_params sparams = llama_sampler_chain_default_params();
    llama_sampler* sampler = llama_sampler_chain_init(sparams);

    // Add samplers to chain (temperature sampling)
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.7f));
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(42)); // seed

    // Step 4: Store state
    llama_state_t* state = new llama_state_t();
    state->model = model;
    state->context = ctx;
    state->vocab = vocab;
    state->sampler = sampler;

    // Log model info
    const int n_vocab = llama_vocab_n_tokens(vocab);
    const int n_ctx_train = llama_model_n_ctx_train(model);
    const int n_embd = llama_model_n_embd(model);

    NSLog(@"✅ [llama_ios.cpp] SUCCESS: Model initialized");
    NSLog(@"   - Vocab size: %d", n_vocab);
    NSLog(@"   - Training context: %d", n_ctx_train);
    NSLog(@"   - Embedding size: %d", n_embd);
    NSLog(@"   - State pointer: %p", (void*)state);

    return state;
#else
    return nullptr;
#endif
}

/**
 * Generate text using initialized model (iOS)
 */
const char* generate(void* ctx, const char* prompt, int maxTokens, float temperature) {
    NSLog(@"🚀 [llama_ios.cpp] generate() called");

#if !LLAMA_CPP_AVAILABLE
    NSLog(@"❌ [llama_ios.cpp] FAILED: llama.cpp not integrated yet!");
    const char* error = "Error: llama.cpp not integrated. Build library first.";
    char* cstr = new char[strlen(error) + 1];
    strcpy(cstr, error);
    return cstr;
#endif

    if (!ctx || !prompt) {
        NSLog(@"❌ [llama_ios.cpp] FAILED: Invalid parameters");
        return nullptr;
    }

    if (maxTokens < 1 || maxTokens > 512) maxTokens = 200;
    if (temperature < 0.0f || temperature > 2.0f) temperature = 0.7f;

#if LLAMA_CPP_AVAILABLE
    llama_state_t* state = static_cast<llama_state_t*>(ctx);
    if (!state->model || !state->context || !state->vocab) {
        NSLog(@"❌ [llama_ios.cpp] FAILED: Invalid state");
        return nullptr;
    }

    NSLog(@"📋 [llama_ios.cpp] Generate parameters:");
    NSLog(@"   - Prompt length: %zu chars", strlen(prompt));
    NSLog(@"   - Max tokens: %d", maxTokens);
    NSLog(@"   - Temperature: %.2f", temperature);

    // Step 1: Tokenize prompt
    const int prompt_len = (int)strlen(prompt);
    std::vector<llama_token> tokens;
    tokens.resize(prompt_len + 256);

    int n_tokens = llama_tokenize(
        state->vocab,
        prompt,
        prompt_len,
        tokens.data(),
        (int)tokens.size(),
        true,  // add_bos
        true   // special
    );

    if (n_tokens < 0) {
        tokens.resize(-n_tokens);
        n_tokens = llama_tokenize(
            state->vocab,
            prompt,
            prompt_len,
            tokens.data(),
            (int)tokens.size(),
            true,
            true
        );
        if (n_tokens < 0) {
            NSLog(@"❌ [llama_ios.cpp] FAILED: Tokenization error");
            return nullptr;
        }
    }

    tokens.resize(n_tokens);
    NSLog(@"   - Tokenized into %zu tokens", tokens.size());

    // Step 2: Clear KV cache (memory)
    llama_memory_t memory = llama_get_memory(state->context);
    if (memory) {
        llama_memory_clear(memory, true);
    }

    // Step 3: Create and decode prompt batch
    llama_batch batch = llama_batch_init((int32_t)tokens.size(), 0, 1);
    batch.n_tokens = (int32_t)tokens.size();
    for (size_t i = 0; i < tokens.size(); i++) {
        batch.token[i] = tokens[i];
        batch.pos[i] = (llama_pos)i;
        batch.n_seq_id[i] = 1;
        batch.seq_id[i][0] = 0;
        batch.logits[i] = (i == tokens.size() - 1);
    }

    if (llama_decode(state->context, batch) != 0) {
        NSLog(@"❌ [llama_ios.cpp] FAILED: Could not decode prompt");
        llama_batch_free(batch);
        return nullptr;
    }

    llama_batch_free(batch);

    // Step 4: Generate tokens
    std::string generated;
    int n_cur = (int)tokens.size();
    int n_decode = 0;

    // Reset sampler
    llama_sampler_reset(state->sampler);

    while (n_decode < maxTokens) {
        // Sample next token using sampler chain
        llama_token new_token = llama_sampler_sample(state->sampler, state->context, -1);

        // Accept token in sampler
        llama_sampler_accept(state->sampler, new_token);

        // Check for end of sequence
        if (llama_vocab_is_eog(state->vocab, new_token)) {
            NSLog(@"   - EOS token generated at position %d", n_cur);
            break;
        }

        // Decode token to string
        char piece[256];
        int n_piece = llama_token_to_piece(state->vocab, new_token, piece, sizeof(piece), 0, true);
        if (n_piece > 0) {
            generated += std::string(piece, n_piece);
        }

        // Decode next token
        llama_batch batch_next = llama_batch_init(1, 0, 1);
        batch_next.n_tokens = 1;
        batch_next.token[0] = new_token;
        batch_next.pos[0] = n_cur;
        batch_next.n_seq_id[0] = 1;
        batch_next.seq_id[0][0] = 0;
        batch_next.logits[0] = true;

        if (llama_decode(state->context, batch_next) != 0) {
            NSLog(@"⚠️ [llama_ios.cpp] Decode failed at position %d", n_cur);
            llama_batch_free(batch_next);
            break;
        }

        llama_batch_free(batch_next);
        n_cur++;
        n_decode++;

        if (n_decode % 10 == 0) {
            NSLog(@"   - Generated %d tokens...", n_decode);
        }
    }

    NSLog(@"✅ [llama_ios.cpp] SUCCESS: Generated %d tokens", n_decode);

    // Clean up output
    std::string result = generated;

    // Remove ChatML tags
    size_t start_pos = result.find("<|im_start|>assistant");
    if (start_pos != std::string::npos) {
        start_pos = result.find("\n", start_pos);
        if (start_pos != std::string::npos) {
            result = result.substr(start_pos + 1);
        }
    }

    size_t end_pos = result.find("<|im_end|>");
    if (end_pos != std::string::npos) {
        result = result.substr(0, end_pos);
    }

    // Trim whitespace
    while (!result.empty() && (result[0] == ' ' || result[0] == '\n')) {
        result = result.substr(1);
    }
    while (!result.empty() && (result.back() == ' ' || result.back() == '\n')) {
        result.pop_back();
    }

    if (result.empty()) {
        const char* empty_msg = "[No output generated]";
        char* cstr = new char[strlen(empty_msg) + 1];
        strcpy(cstr, empty_msg);
        return cstr;
    }

    char* cstr = new char[result.length() + 1];
    strncpy(cstr, result.c_str(), result.length());
    cstr[result.length()] = '\0';

    return cstr;
#else
    return nullptr;
#endif
}

/**
 * Release model and free memory (iOS)
 */
void releaseLlama(void* ctx) {
    NSLog(@"🚀 [llama_ios.cpp] releaseLlama() called");

#if !LLAMA_CPP_AVAILABLE
    NSLog(@"⚠️ [llama_ios.cpp] llama.cpp not integrated - nothing to release");
    (void)ctx;
#else
    if (!ctx) {
        NSLog(@"⚠️ [llama_ios.cpp] Context pointer is null");
        return;
    }

    llama_state_t* state = static_cast<llama_state_t*>(ctx);

    NSLog(@"📋 [llama_ios.cpp] Releasing llama model...");

    if (state->sampler) {
        llama_sampler_free(state->sampler);
        state->sampler = nullptr;
        NSLog(@"   - Sampler freed");
    }

    if (state->context) {
        llama_free(state->context);
        state->context = nullptr;
        NSLog(@"   - Context freed");
    }

    if (state->model) {
        llama_model_free(state->model);
        state->model = nullptr;
        NSLog(@"   - Model freed");
    }

    delete state;

    llama_backend_free();

    NSLog(@"✅ [llama_ios.cpp] SUCCESS: Model released");
#endif
}

} // extern "C"
