import { Response } from "express";
import { KeyValuePair } from "./key-value-pair";

declare global {
  namespace Express {
    interface Response {
      simpleResponse: SimpleResponse;
    }
  }
}

export class SimpleResponse {
  private _devMessage: string;
  private _message: string;
  private _data: KeyValuePair<any>;
  private _code: number;
  private _error: boolean;
  private _res: Response;

  /**
   * Constructor
   * @param {*} res Express result
   */
  constructor(res: Response) {
    this._res = res;
    this._data = {};
    this._code = 200;
    this._message = "";
    this._devMessage = "";
    this._error = false;
  }

  /**
   * Create a 2xx HTTP result
   * @param {string} message User friendly message
   * @param {*} data optional data paramter
   */
  success(message?: string, data?: any) {
    this._message = message ?? "Request successful.";
    this._data = data ?? this._data ?? {};
    this._code = 200;
    this._error = false;
    return this;
  }

  /**
   * Create a 4xx HTTP result
   * @param {*} message Optional user friendly message
   * @param {*} data optional data paramter
   */
  error(message?: string, data?: any) {
    this._message = message ?? "Oops, something went wrong!";
    this._data = data ?? {};
    this._code = 404;
    this._error = true;
    return this;
  }

  /**
   * Standard unauthorized response
   * @param {*} data optional data
   */
  unauthorized(data?: KeyValuePair<any>) {
    this._message = "Oops, you are not authorized to complete this action!";
    if (data) this._data = data;
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
   * Include data in result
   * @param {Object} data
   */
  setData(data: Object) {
    this._data = data ?? {};
    return this;
  }

  /**
   * Return final status result
   */
  send() {
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
