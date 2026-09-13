# Image operation registry design (Phase 6)

## Purpose and scope

Phase 6 introduces `ImageLab::OperationRegistry`, the one explicit authority
for image operations that the API may expose and accept. It establishes a safe
extension point for the operation implementations planned for later phases.

This phase deliberately registers no operations. It does not implement image
transforms, advertise future operation names, add routes, add dependencies, or
change the successful Phase 5 response format.

## Components and data flow

`app/services/image_lab/operation_registry.rb` owns the registered-operation
mapping and validates an incoming operation array. Its public interface serves
two callers:

```ruby
ImageLab::OperationRegistry.available # => []
ImageLab::OperationRegistry.validate!(operations) # => validated operations
```

`ImagesController#capabilities` derives its `operations` JSON field from
`available`, rather than maintaining a separate controller list.

`ImagesController#process_image` passes the parsed request value to
`validate!` before image qualification. An empty array succeeds. Any
non-empty array contains an operation that is not registered in Phase 6 and
therefore receives the established JSON 422 validation response.

The registry never calls `public_send`, `send`, `constantize`, or another
dynamic dispatch mechanism using a client-provided string. A future phase must
add an operation only by explicitly adding it to the registry's controlled
mapping after its implementation exists.

## Operation request policy

The `operations` request value must be an array. It may contain at most
`IMAGE_MAX_OPERATIONS` entries, with a default of 16. A missing, blank,
non-numeric, or non-positive environment value uses the safe default.

Each entry must be an object with an `"op"` key whose value is a non-empty
string. The registry rejects malformed entries before attempting lookup. A
well-formed name absent from the controlled mapping is unsupported.

The empty initial mapping is intentional: it keeps the published capability
contract truthful until Phase 7 adds actual image operations.

## Errors and HTTP behavior

`ImageLab::Errors` gains domain errors for malformed operations, unsupported
operation names, and operation-count limits. `ImagesController` rescues these
alongside the existing input-validation errors and renders the existing
single-key error object with HTTP 422:

```json
{
  "error": "..."
}
```

Authentication failures, malformed JSON parsing failures, application bugs,
and unrelated infrastructure failures keep their existing behavior.

## Test strategy

Registry unit tests are written before production code. They cover an empty
array, invalid top-level values, malformed entries, an unregistered operation,
the configurable count limit, and invalid environment configuration falling
back to the default.

Controller tests retain the Phase 4/5 contract: an authenticated request with
`operations: []` and a valid PNG succeeds; a non-empty operation list returns
JSON 422; and capabilities reports the current registry result (`[]`). The
full suite verifies that authentication, input validation, output headers, and
other prior behavior remain intact.

## Explicit non-goals

- No resize, crop, rotate, grayscale, AI, or other image operation is
  implemented or advertised.
- No operation execution pipeline is introduced.
- No route, persistence, background job, database, or dependency changes are
  made.
- No client-supplied method/class name is dynamically resolved.
