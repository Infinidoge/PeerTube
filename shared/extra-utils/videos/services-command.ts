import { HttpStatusCode } from '../../core-utils/miscs/http-error-codes'
import { AbstractCommand, OverrideCommandOptions } from '../shared'

export class ServicesCommand extends AbstractCommand {

  getOEmbed (options: OverrideCommandOptions & {
    oembedUrl: string
    format?: string
    maxHeight?: number
    maxWidth?: number
  }) {
    const path = '/services/oembed'
    const query = {
      url: options.oembedUrl,
      format: options.format,
      maxheight: options.maxHeight,
      maxwidth: options.maxWidth
    }

    return this.getRequest({
      ...options,

      path,
      query,
      defaultExpectedStatus: HttpStatusCode.OK_200
    })
  }
}
