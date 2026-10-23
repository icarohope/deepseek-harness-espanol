/**
 * Host half of `dsh-locale-es`.
 *
 * The translation is a browser-only concern: every dictionary is registered
 * through the client-side locale service (`ctx.locale`), so the Host loader
 * entry only has to exist for the row to mount and for the client module
 * system to discover the package's `dsh.client` declaration.
 */

/** Provides no host-side behavior. */
export function apply() {}
