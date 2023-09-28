import { Response, Request } from "express";
import { FirebaseAuthMiddleware } from "../../firebase_auth_middleware";
import { KeyValuePair } from "./key-value-pair";

declare global {
  namespace Express {
    interface Response {
      simpleResponse: SimpleResponse;
    }
  }
}

/// The REST method types.
export enum FromMethod {
  GET,
  POST,
}

/**
 * Get the POST request data.
 * @param req Request node express.
 * @param method of GET or POST type.
 */
export function getRequestData(req: Request, method: FromMethod) {
  if (method === FromMethod.POST) return JSON.parse(req.body.request as string);
  else if (method === FromMethod.GET)
    return JSON.parse(req.query.request as string);
}

export class SimpleResponse {
  private _devMessage: string;
  private _message: string;
  private _data: KeyValuePair<any>;
  private _code: number;
  private _error: boolean;
  private _res: Response;
  private _req: Request;
  private _isPublic: boolean;

  static _defaultIsPublic = false;

  static initDefault(option: { isPublic: boolean}) {
    this._defaultIsPublic = option.isPublic
  }

  /**
   * Constructor
   * @param {*} res Express result
   */
  constructor(req: Request, res: Response) {
    const initMess = "Simple response must call success or error method.";
    this._req = req;
    this._res = res;
    this._data = {};
    this._code = 200;
    this._message = initMess;
    this._devMessage = initMess;
    this._error = true;
    this._isPublic = SimpleResponse._defaultIsPublic;
  }

  /**
   * Create a 2xx HTTP result
   * @param {string} message User friendly message
   * @param {*} data optional data paramter
   */
  success(message?: string) {
    this._message = message ?? "Request successful.";
    this._code = 200;
    this._error = false;
    return this;
  }

  /**
   * Create a 4xx HTTP result
   * @param {*} message Optional user friendly message
   * @param {*} data optional data paramter
   */
  error(message?: string) {
    this._message = message ?? "Oops, something went wrong!";
    this._code = 404;
    this._error = true;
    return this;
  }

  /**
   * Standard unauthorized response
   * @param {*} data optional data
   */
  unauthorized() {
    this._message = "Oops, you are not authorized to complete this action!";
    this._code = 403;
    this._error = true;
    return this;
  }

  /**
   * Override standard HTTP codes
   * @param {number} code valid HTTP code.
   */
  setCode(code: number) {
    //Validate HTTP code before setting it.
    const validCode = /^[1-5][0-9][0-9]$/;
    if (validCode.test(code.toString())) this._code = code;
    else throw new Error("Invalid HTTP code.");
    return this;
  }

  /**
   * Set dev message as code error.
   * @param message
   */
  setDevMessage(message: string) {
    this._devMessage = message;
    return this;
  }

  /**
   * Override standard messages
   * @param {string} message user friendly message;
   */
  setMessage(message: string) {
    this._message = message;
    return this;
  }

  /**
   * Include data in result. This function
   * does not stringify JSON object.
   *
   * Recommend to use "responseData()" instead
   * of this function,
   *
   * @param {Object} data
   */
  setData(data: Object) {
    this._data = data ?? {};
    return this;
  }

  /**
   * Set the response data, this function
   * will parse to JSON string.
   * @param {Object}
   */
  setResponseData(data: Object) {
    this._data["response"] = JSON.stringify(data ?? {});
    return this;
  }

  /**
   * Determines whether or not to run middleware
   * related to authorizing an endpoint
   * @param isPublic
   */
  setPublic(isPublic: boolean) {
    this._isPublic = isPublic;
    return this;
  }

  /**
   * Return final status result
   */
  async send(): Promise<void> {

    if (!this._isPublic) {
      await FirebaseAuthMiddleware.validateIdToken(this._req,this._res);
    }

    //If code is undefined send an error 500
    if (this._code === undefined || this._code === null) {
      this._code = 500;
      this._error = true;
      this._message = "An unknown error has occurred!";
    }

    //Wrap result in error/success
    const result: KeyValuePair<any> = {};
    result[this._error ? "error" : "success"] = {
      message: this._message,
      devMessage: this._devMessage,
      data: this._data,
    };

    //Return the express result
    this._res.status(this._code).json(result);
  }
}
