## [Unreleased]

## [1.0.0] - Unreleased

### Added

- Deduplicate identical preload callbacks.
- Warn when skipping preloading for exposures with dynamic key or dynamic attr_path.

### Changed

- **Breaking**: Merge `:preload_association`, `:preload_callback`, and `:preload_condition` into a single `:preload` option on exposures. The option now accepts:
  - a Symbol for an ActiveRecord association (`preload: :books`);
  - a Proc for a callback (`preload: ->(objects, options) { ... }`);
  - an Array combining the above with an optional condition Proc (`preload: [:books, ->(options) { ... }]` or `preload: [->(objects, options) { ... }, ->(options) { ... }]`).
- **Breaking**: Require `preload_callback` Proc to return a Hash mapping each object to its preloaded value, instead of an Array of values. Preloaded values are cached in `options` and reused across exposures at the same nesting level.
- Defer ActiveRecord version check to runtime.

### Fixed

- Keep consistent `attr_path` for nested exposures when preloader is enabled.
- Disable preloader during nested entity serialization instead of at root `represent`, preventing duplicate preloads for deferred serialization.
- Fix cyclic entity references during preload option extraction to avoid infinite recursion.

## [0.3.0] - 2026-03-17 UTC

- Ensure `with_enable` and `with_disable` methods return block result

## [0.2.0] - 2025-10-14 UTC

- ⚠️ [Broken] Remove `:grape_entity_preloader` option functionality, please use `Grape::Entity::Preloader.with_enable` or `Grape::Entity::Preloader.with_disable` instead.

## [0.1.0] - 2025-10-12 UTC

- Initial release
