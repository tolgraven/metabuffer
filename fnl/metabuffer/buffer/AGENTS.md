# Buffer Subsystem

Buffer modules own Meta-managed buffer state and buffer-local policy. They should not orchestrate session lifecycle or window layout. That work belongs in `router/` and `window/`.

## Responsibilities

### `base.fnl`
- Shared managed-buffer primitives.
- Applies and restores buffer-local options.
- Clears `modified` safely on teardown or buffer swapping.
- This is the place for generic buffer-wrapper behavior that prompt/info/preview/meta buffers all share.

### `metabuffer.fnl`
- Main results buffer wrapper.
- Owns result rendering, source-ref bookkeeping, cursor-line mapping, source separators, and visible-edit preparation.
- If logic is about how result rows are represented in the main buffer, it belongs here rather than in `prompt/hooks` or window modules.

### `prompt.fnl`
- Prompt buffer wrapper.
- Buffer-local prompt options, naming, and lifecycle for the prompt buffer itself.
- Prompt-specific rendering/highlight policy should prefer this layer over `prompt/hooks` when it is actually about buffer content, not autocmd registration.

### `prompt_view.fnl`
- Prompt display/render helpers.
- Owns prompt-line highlighting and display shaping.
- `prompt/hooks.fnl` should call into this module instead of directly doing highlight work.

### `info.fnl`
- Info buffer wrapper.
- Buffer-local options and lifecycle for the info panel buffer.
- If the work is about info-buffer contents or write safety, it belongs here rather than in prompt or window orchestration.

### `preview.fnl`
- Preview buffer wrapper.
- Buffer-local options and lifecycle for preview content buffers.

### `regular.fnl`
- Tracks the origin/source buffer for a session.

### `ui.fnl`
- Shared UI buffer helpers such as namespaces, highlights, and extmark-oriented helpers.

### `init.fnl`
- Barrel module returning the public buffer modules.

## Boundaries

- `buffer/` owns buffer-local options and content-oriented helpers.
- `window/` owns where and how buffers are shown.
- `prompt/hooks.fnl` should register autocmds and dispatch to these modules, not perform large amounts of direct buffer mutation inline.
- `router/` sequences lifecycle and cross-subsystem flow.

## Caution Points

- Keep buffer wrappers narrow and role-specific. Avoid reintroducing giant constructors by moving unrelated orchestration into them.
- Shared logic should go in `base.fnl` only when it is truly generic across multiple buffer roles.
