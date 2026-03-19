const { expressjwt: jwt } = require("express-jwt");
const jwksRsa = require("jwks-rsa");
const config = require("../config");

/**
 * JWT validation middleware.
 * Validates access tokens issued by Entra ID using the JWKS endpoint.
 * Decoded payload is available on req.auth.
 */
const authenticate = jwt({
  secret: jwksRsa.expressJwtSecret({
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 10,
    jwksUri: config.jwksUri,
  }),
  audience: `api://${config.clientId}`,
  issuer: config.issuers,
  algorithms: ["RS256"],
});

/**
 * RBAC authorization middleware factory.
 * Checks that the authenticated user has at least one of the required roles
 * in the token's "roles" claim (App Roles assigned in Entra ID).
 *
 * @param  {...string} allowedRoles - Roles that are permitted access.
 * @returns {Function} Express middleware
 */
function authorize(...allowedRoles) {
  return (req, res, next) => {
    if (!req.auth) {
      return res.status(401).json({ error: "Not authenticated" });
    }

    const userRoles = req.auth.roles || [];

    if (allowedRoles.length === 0) {
      return next();
    }

    const hasRole = allowedRoles.some((role) => userRoles.includes(role));
    if (!hasRole) {
      return res.status(403).json({
        error: "Forbidden",
        message: `Required roles: ${allowedRoles.join(", ")}`,
      });
    }

    next();
  };
}

module.exports = { authenticate, authorize };
