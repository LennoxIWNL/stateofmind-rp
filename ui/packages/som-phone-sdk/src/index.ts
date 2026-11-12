/**
 * @som/phone-sdk
 *
 * The only thing a phone app may import (enforced by a test). An app asks the
 * server for data and for actions and draws what comes back; it holds no
 * authority, so editing one buys a nicer screen and nothing else.
 */

export { callApp, callHousing, closePhone, type ActionResult } from './bridge'
export { PhoneContext, usePhone, type PhoneApi } from './context'
export { Icon, ICON_NAMES } from './icons'
export { Empty, Row, Section, Segment, Pill, money, digits } from './ui'
