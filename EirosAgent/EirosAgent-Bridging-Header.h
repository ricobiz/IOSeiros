//
//  EirosAgent-Bridging-Header.h
//  EirosAgent
//
//  Created by DeepAgent on 2025-09-21.
//

#ifndef EirosAgent_Bridging_Header_h
#define EirosAgent_Bridging_Header_h

// C and C++ headers for llama.cpp integration
#ifdef __cplusplus
extern "C" {
#endif

// Basic types for llama.cpp integration
typedef struct llama_context llama_context;
typedef struct llama_model llama_model;

// Function declarations for llama.cpp bridge
// These would be implemented in a separate .cpp file

/**
 * Initialize llama.cpp library
 */
int llamacpp_init(void);

/**
 * Load a model from file path
 * @param model_path Path to the GGUF model file
 * @param n_ctx Context size
 * @param n_gpu_layers Number of layers to offload to GPU (Metal Performance Shaders)
 * @return Opaque pointer to model context or NULL on failure
 */
void* llamacpp_load_model(const char* model_path, int n_ctx, int n_gpu_layers);

/**
 * Generate text response
 * @param context Model context pointer
 * @param prompt Input prompt
 * @param max_tokens Maximum tokens to generate
 * @param temperature Sampling temperature
 * @param callback Callback function for streaming results
 * @return Generated text or NULL on failure
 */
char* llamacpp_generate(void* context, const char* prompt, int max_tokens, float temperature, void(*callback)(const char*));

/**
 * Free model context and cleanup
 * @param context Model context pointer
 */
void llamacpp_free_model(void* context);

/**
 * Get model information
 * @param context Model context pointer
 * @return JSON string with model info or NULL
 */
char* llamacpp_get_model_info(void* context);

/**
 * Check if model supports GPU acceleration
 * @return 1 if Metal Performance Shaders is available, 0 otherwise
 */
int llamacpp_has_gpu_support(void);

/**
 * Get memory usage in bytes
 * @param context Model context pointer
 * @return Memory usage in bytes
 */
size_t llamacpp_get_memory_usage(void* context);

/**
 * Set logging callback
 * @param callback Logging callback function
 */
void llamacpp_set_log_callback(void(*callback)(int level, const char* message));

// Error codes
#define LLAMACPP_SUCCESS 0
#define LLAMACPP_ERROR_INVALID_MODEL -1
#define LLAMACPP_ERROR_OUT_OF_MEMORY -2
#define LLAMACPP_ERROR_INVALID_CONTEXT -3
#define LLAMACPP_ERROR_GENERATION_FAILED -4

// Model configuration structure
typedef struct {
    int n_ctx;           // Context size
    int n_batch;         // Batch size for prompt processing
    int n_gpu_layers;    // Number of layers to offload to GPU
    float temperature;   // Sampling temperature
    int top_k;           // Top-k sampling
    float top_p;         // Top-p sampling
    float repeat_penalty; // Repetition penalty
    int seed;            // Random seed (-1 for random)
} llamacpp_params;

/**
 * Create default parameters
 * @return Default parameters structure
 */
llamacpp_params llamacpp_default_params(void);

/**
 * Load model with custom parameters
 * @param model_path Path to model file
 * @param params Configuration parameters
 * @return Model context or NULL on failure
 */
void* llamacpp_load_model_with_params(const char* model_path, llamacpp_params params);

#ifdef __cplusplus
}
#endif

#endif /* EirosAgent_Bridging_Header_h */
