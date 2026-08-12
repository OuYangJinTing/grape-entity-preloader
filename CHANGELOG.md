## [Unreleased]

- ⚠️ [Broken] Merge `:preload_association`, `:preload_callback`, and `:preload_condition` into a single `:preload` option.
- ⚠️ [Broken] The `preload_condition` Proc signature has changed from `->(objects, options) { ... }` to `->(options) { ... }`. Passing `objects` was problematic for nested preloading because the condition is evaluated against the top-level objects rather than the objects at the current nesting level.
- ⚠️ [Broken] The `preload_callback` Proc must now return a Hash mapping each object to its preloaded value, instead of an Array of objects. Preloaded values are cached in `options` and reused across exposures.

## [0.3.0] - 2026-03-17 UTC

- Ensure `with_enable` and `with_disable` methods return block result

## [0.2.0] - 2025-10-14 UTC

- ⚠️ [Broken] Remove `:grape_entity_preloader` option functionality, please use `Grape::Entity::Preloader.with_enable` or `Grape::Entity::Preloader.with_disable` instead.

## [0.1.0] - 2025-10-12 UTC

- Initial release
