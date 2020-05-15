/**
 * This class is used as a middleware
 * to be able to use express node in
 * Firebase function, so that you can
 * use the HTTP Bearer Rest API Authorization method.
 * Credit: https://github.com/antonybudianto/express-firebase-middleware#readme
 *
 * @summary A middleware to be able to use express auth.
 * @author Vicky Mohammad
 *
 * Created at     : 2020-01-01 20:05:53
 * Last modified  : 2020-05-15 03:47:25
 */

import * as admin from 'firebase-admin';
const debug = process.env.APP_DEBUG === 'true';

/**
 * This class is used as Middleware
 * to be able to use express node in
 * Firebase function, so that you can
 * use the HTTP Bearer Rest API Authorization method.
 */
export class FirebaseAuthMiddleware {
  /**
   * Function to show console
   * @param val String or anything to be shown on console
   */
  private static log(val: any) {
    if (!debug) return;
    console.log(val);
  }

  /**
   * Function callback. Pass this function
   * when you initialize the firebase.
   * @deprecated use the validate id token instead.
   * @param req
   * @param res
   * @param next
   */
  public static auth(req: any, res: any, next: any) {
    const authorization = req.header('Authorization');
    if (authorization) {
      const token = authorization.split(' ');
      admin
        .auth()
        .verifyIdToken(token[1])
        .then((decodedToken) => {
          FirebaseAuthMiddleware.log(decodedToken);
          res.locals.user = decodedToken;
          next();
        })
        .catch((err) => {
          FirebaseAuthMiddleware.log(err);
          res.sendStatus(401);
        });
    } else {
      FirebaseAuthMiddleware.log('Authorization header is not found');
      res.sendStatus(401);
    }
  }

  /**
   * Function callback for validating the Firebase auth token
   * for the bearer authorization. Sends 403 if it is not authorized.
   *
   * Example:
   *
   * ```
   * // Declare this at the top.
   * const cookieParser = require('cookie-parser')();
   * const cors = require('cors')({ origin: true });
   *
   * // Using the validation.
   * app.use(cors);
   * app.use(cookieParser);
   * app.use(validateIdToken);
   *
   * // This HTTPS endpoint can only be accessed by your Firebase Users.
   * // Requests need to be authorized by providing an `Authorization` HTTP header
   * // with value `Bearer <Firebase ID Token>`.
   * exports.app = functions.https.onRequest(app)
   * ```
   *
   * @param req
   * @param res
   * @param next
   */
  public static async validateIdToken(req: any, res: any, next: any = null) {
    console.log('Check if request is authorized with Firebase ID token');

    if (
      (!req.headers.authorization ||
        !req.headers.authorization.startsWith('Bearer ')) &&
      !(req.cookies && req.cookies.__session)
    ) {
      console.error(
        'No Firebase ID token was passed as a Bearer token in the Authorization header.',
        'Make sure you authorize your request by providing the following HTTP header:',
        'Authorization: Bearer <Firebase ID Token>',
        'or by passing a "__session" cookie.'
      );
      res.status(403).send('Unauthorized');
      return;
    }

    let idToken;
    if (
      req.headers.authorization &&
      req.headers.authorization.startsWith('Bearer ')
    ) {
      console.log('Found "Authorization" header');
      // Read the ID Token from the Authorization header.
      idToken = req.headers.authorization.split('Bearer ')[1];
    } else if (req.cookies) {
      console.log('Found "__session" cookie');
      // Read the ID Token from cookie.
      idToken = req.cookies.__session;
    } else {
      // No cookie
      res.status(403).send('Unauthorized');
      return;
    }

    try {
      const decodedIdToken = await admin.auth().verifyIdToken(idToken);
      console.log('ID Token correctly decoded', decodedIdToken);
      req.user = decodedIdToken;
      if (!(next === null || next === undefined)) next();
      return;
    } catch (error) {
      console.error('Error while verifying Firebase ID token:', error);
      res.status(403).send('Unauthorized');
      return;
    }
  }
}
