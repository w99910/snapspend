# Llama FFI API Reference

This document provides a quick reference for the most commonly used functions from the llama.cpp bindings.

## Initialization & Backend

### Backend Management
```dart
// Initialize the backend (call once at startup)
bindings.llama_backend_init();

// Free backend resources (call at shutdown)
bindings.llama_backend_free();

// Get number of available backends
int count = bindings.ggml_backend_reg_count();
```

### Logging
```dart
// Set log callback
typedef LogCallback = void Function(
  int level,
  Pointer<Char> text,
  Pointer<Void> userData
);

bindings.llama_log_set(logCallback, userData);
```

## Model Management

### Loading Models
```dart
// Get default model parameters
final params = bindings.llama_model_default_params();

// Load model from file
final model = bindings.llama_model_load_from_file(
  modelPath.toNativeUtf8().cast(),
  params,
);

// Free model
bindings.llama_model_free(model);
```

### Model Information
```dart
// Get model description
Pointer<Char> desc = bindings.llama_model_desc(model);

// Get model size in bytes
int size = bindings.llama_model_size(model);

// Get number of parameters
int params = bindings.llama_model_n_params(model);

// Get model metadata
int kvCount = bindings.llama_model_meta_count(model);
Pointer<Char> key = bindings.llama_model_meta_key_by_index(model, index);
Pointer<Char> value = bindings.llama_model_meta_val_str_by_index(model, index);
```

## Context Management

### Creating Contexts
```dart
// Get default context parameters
final ctxParams = bindings.llama_context_default_params();

// Create context with model
final ctx = bindings.llama_new_context_with_model(model, ctxParams);

// Free context
bindings.llama_free(ctx);
```

### Context Operations
```dart
// Get context size (number of tokens)
int size = bindings.llama_n_ctx(ctx);

// Get batch size
int batch = bindings.llama_n_batch(ctx);

// Get embedding dimension
int embd = bindings.llama_n_embd(model);

// Clear KV cache
bindings.llama_kv_cache_clear(ctx);
```

## Tokenization

### Token Operations
```dart
// Tokenize text
final tokens = calloc<llama_token>(maxTokens);
int nTokens = bindings.llama_tokenize(
  model,
  text.toNativeUtf8().cast(),
  textLength,
  tokens,
  maxTokens,
  addSpecial,    // add BOS/EOS tokens
  parseSpecial,  // parse special tokens
);

// Detokenize (token to text)
Pointer<Char> text = bindings.llama_token_to_piece(
  model,
  token,
  buffer,
  bufferLength,
  specialHandling,
);

// Get special tokens
llama_token bos = bindings.llama_token_bos(model);  // Beginning of sequence
llama_token eos = bindings.llama_token_eos(model);  // End of sequence
llama_token eot = bindings.llama_token_eot(model);  // End of turn
llama_token nl = bindings.llama_token_nl(model);    // Newline
```

## Text Generation

### Batch Processing
```dart
// Create a batch
final batch = bindings.llama_batch_init(nTokens, embdSize, maxSeq);

// Free batch
bindings.llama_batch_free(batch);

// Add token to batch
bindings.llama_batch_add(
  batch,
  token,
  pos,
  sequenceIds,
  logits,
);

// Decode batch
int result = bindings.llama_decode(ctx, batch);
```

### Sampling
```dart
// Get logits
Pointer<Float> logits = bindings.llama_get_logits(ctx);
Pointer<Float> logitsIth = bindings.llama_get_logits_ith(ctx, i);

// Sample next token (simplified approach)
llama_token token = bindings.llama_sampler_sample(sampler, ctx, idx);
```

### Sampling Context
```dart
// Create sampler chain
final sampler = bindings.llama_sampler_chain_init(params);

// Add samplers to chain
bindings.llama_sampler_chain_add(sampler, temperature_sampler);
bindings.llama_sampler_chain_add(sampler, top_k_sampler);
bindings.llama_sampler_chain_add(sampler, top_p_sampler);

// Free sampler
bindings.llama_sampler_free(sampler);
```

## Embeddings

### Generate Embeddings
```dart
// Get embeddings for sequence
Pointer<Float> embeddings = bindings.llama_get_embeddings(ctx);

// Get embedding for specific token
Pointer<Float> embdIth = bindings.llama_get_embeddings_ith(ctx, i);

// Get sequence embeddings
Pointer<Float> seqEmbd = bindings.llama_get_embeddings_seq(ctx, seqId);
```

## Memory Management

### State Saving/Loading
```dart
// Get state size
int stateSize = bindings.llama_state_get_size(ctx);

// Save state
int written = bindings.llama_state_save_file(
  ctx,
  path.toNativeUtf8().cast(),
  tokens,
  nTokens,
);

// Load state
int read = bindings.llama_state_load_file(
  ctx,
  path.toNativeUtf8().cast(),
  tokens,
  nTokensCapacity,
  outNTokens,
);
```

## Performance & System Info

### Timing
```dart
// Get timing information
final timings = bindings.llama_perf_context(ctx);
bindings.llama_perf_context_print(ctx);
bindings.llama_perf_context_reset(ctx);
```

### System Information
```dart
// Get system info string
Pointer<Char> info = bindings.llama_print_system_info();
```

## GGML Tensor Operations

### Tensor Creation
```dart
// Initialize GGML context
final initParams = calloc<ggml_init_params>();
initParams.ref.mem_size = memSize;
initParams.ref.mem_buffer = nullptr;
final ggmlCtx = bindings.ggml_init(initParams.ref);

// Create tensors
final tensor1d = bindings.ggml_new_tensor_1d(ggmlCtx, type, ne0);
final tensor2d = bindings.ggml_new_tensor_2d(ggmlCtx, type, ne0, ne1);
final tensor3d = bindings.ggml_new_tensor_3d(ggmlCtx, type, ne0, ne1, ne2);
final tensor4d = bindings.ggml_new_tensor_4d(ggmlCtx, type, ne0, ne1, ne2, ne3);

// Free GGML context
bindings.ggml_free(ggmlCtx);
```

## GGUF File Format

### Reading GGUF Files
```dart
// Initialize GGUF context
final ggufCtx = bindings.gguf_init_from_file(
  path.toNativeUtf8().cast(),
  params,
);

// Get metadata
int kvCount = bindings.gguf_get_n_kv(ggufCtx);
Pointer<Char> key = bindings.gguf_get_key(ggufCtx, keyId);

// Get tensors
int tensorCount = bindings.gguf_get_n_tensors(ggufCtx);
Pointer<Char> tensorName = bindings.gguf_get_tensor_name(ggufCtx, i);

// Free GGUF context
bindings.gguf_free(ggufCtx);
```

## Error Handling

Most functions return:
- `nullptr` or negative values on error
- Valid pointers or non-negative values on success

Always check return values:

```dart
final model = bindings.llama_model_load_from_file(path.cast(), params);
if (model == nullptr) {
  throw Exception('Failed to load model');
}
```

## Common Patterns

### Complete Text Generation Example
```dart
// 1. Initialize
bindings.llama_backend_init();

// 2. Load model
final modelParams = bindings.llama_model_default_params();
final model = bindings.llama_model_load_from_file(modelPath.cast(), modelParams);

// 3. Create context
final ctxParams = bindings.llama_context_default_params();
final ctx = bindings.llama_new_context_with_model(model, ctxParams);

// 4. Tokenize prompt
final tokens = calloc<llama_token>(512);
final nTokens = bindings.llama_tokenize(
  model, prompt.cast(), promptLen, tokens, 512, true, true
);

// 5. Create batch and decode
final batch = bindings.llama_batch_init(nTokens, 0, 1);
// Add tokens to batch...
bindings.llama_decode(ctx, batch);

// 6. Sample and generate
final logits = bindings.llama_get_logits_ith(ctx, nTokens - 1);
// Sample next token...

// 7. Cleanup
bindings.llama_batch_free(batch);
calloc.free(tokens);
bindings.llama_free(ctx);
bindings.llama_model_free(model);
bindings.llama_backend_free();
```

## Type Definitions

Key types used throughout the API:

- `llama_token` - Token ID (int32)
- `llama_pos` - Position in sequence (int32)
- `llama_seq_id` - Sequence ID (int32)
- `llama_model` - Pointer to model
- `llama_context` - Pointer to context
- `ggml_type` - Enum for tensor data types
- `ggml_tensor` - Pointer to tensor

For complete type information, see the generated bindings in `lib/src/llama_bindings_generated.dart`.










