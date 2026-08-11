/**
 * @som/ui-kit
 *
 * Every SOM NUI built from here imports its pieces from this one place, so a
 * change to how a card or a button looks lands everywhere at once instead of
 * in whichever screen someone remembers to update.
 *
 * Consumers must also import the stylesheet:
 *
 *   import '@som/ui-kit/kit.css'
 *
 * and their index.html must link tokens.css, which is what the kit's
 * var(--som-*) references resolve against:
 *
 *   <link rel="stylesheet" href="https://cfx-nui-som-assets/tokens.css">
 */

export {
  Card,
  Button,
  IconTile,
  StatusBadge,
  Meter,
  type CardProps,
  type ButtonProps,
  type ButtonVariant,
  type IconTileProps,
  type StatusBadgeProps,
  type StatusTone,
  type MeterProps,
} from './components/primitives'

export {
  Modal,
  Drawer,
  ContextMenu,
  type ModalProps,
  type DrawerProps,
  type ContextMenuProps,
  type ContextMenuItem,
} from './components/overlays'

export {
  Input,
  Select,
  Stepper,
  Tabs,
  type InputProps,
  type SelectProps,
  type SelectOption,
  type StepperProps,
  type TabsProps,
  type TabItem,
} from './components/forms'

export {
  fetchNui,
  useNuiEvent,
  useNuiVisibility,
  debugData,
  RESOURCE_NAME,
  IS_BROWSER,
  type NuiMessage,
  type VisibilityOptions,
} from './nui'
