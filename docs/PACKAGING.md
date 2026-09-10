# Packaging notes

This is a source-only copy, not a complete server backup. Gameplay Lua is unchanged from the provided archive. The custom schema and included addon source were byte-compared with the extracted originals. The supplied Helix runtime and database repair code are retained; its documentation website assets were omitted.

Checks performed: safe archive paths, selected-source byte comparisons, forbidden binary/database/archive exclusions, common embedded credential patterns, and ZIP CRC verification. The manifest records SHA-256 hashes for the payload files other than this report and the manifest itself. There is no Git history or remote configuration in this package.

No Garry's Mod runtime was available for gameplay testing. Existing gameplay behavior and compatibility issues in the source snapshot may remain. External dependencies are required for the corresponding features. This packaging pass does not establish redistribution rights for every custom asset and does not assign a new project-wide license.
