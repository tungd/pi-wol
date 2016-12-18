module Main where

import Prelude
import Network.HTTP.Affjax as Ajax
import Control.Monad.Aff (Aff, Canceler(..), launchAff)
import Control.Monad.Aff.Class (liftAff)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Eff.Console (CONSOLE, log)
import Control.Monad.Eff.Exception (EXCEPTION)
import Control.Monad.Eff.Timer (TIMER)
import Control.Monad.Except (runExcept, runExceptT)
import DOM (DOM)
import DOM.HTML (window)
import DOM.HTML.HTMLTrackElement.ReadyState (ReadyState(..))
import DOM.HTML.Types (htmlDocumentToParentNode)
import DOM.HTML.Window (document)
import DOM.Node.ParentNode (querySelector)
import DOM.Node.Types (Node, elementToNode)
import Data.Argonaut (class DecodeJson, decodeJson)
import Data.Argonaut.Decode.Combinators ((.?))
import Data.Either (Either(..), either)
import Data.Maybe (Maybe(..), maybe)
import Data.Nullable (toMaybe)
import Data.Tuple (Tuple(..))
import Data.Tuple.Nested ((/\))
import Data.VirtualDOM (patch, VNode, text, prop, h, with, EventListener(On))
import Data.VirtualDOM.DOM (api)
import Network.HTTP.Affjax (AJAX)
import Signal (sampleOn, runSignal, (~>), foldp, Signal)
import Signal.Channel (CHANNEL, Channel, channel, send, subscribe)
import Signal.DOM (animationFrame)
-----------------------------------------------

newtype Machine = Machine
  { name :: String , ip :: String , mac :: String , up :: Boolean }

instance decodeJsonMachine :: DecodeJson Machine where
  decodeJson json = do
    obj <- decodeJson json
    name <- obj .? "name"
    ip <- obj .? "ip"
    mac <- obj .? "mac"
    up <- obj .? "up"
    pure $ Machine { name, ip, mac, up }

type State = Array Machine

data Action = Noop | Load (Array Machine)
-----------------------------------------------

foreign import logRaw :: forall a e. a -> Eff (console :: CONSOLE | e) Unit

init :: State
init = []

render actions state = h "div" (prop ["class" /\ "app"])
  [ h "h1" (prop []) [text "Machines"]
  , h "ul" (prop []) $ map (\(Machine m) -> h "li" (prop []) [text m.ip, text $ show m.up]) state
  ]

update :: Action -> State -> State
update action state = case action of
  Noop -> state
  (Load machines) -> machines

app :: forall e.
  Signal State
  -> Channel Action
  -> Node
  -> Eff (dom :: DOM, channel :: CHANNEL, timer :: TIMER | e) Unit
app state actions target = do
  tick <- animationFrame
  runSignal $ (input (sampleOn tick state)) ~> write
  where
    input state = foldp go (Tuple Nothing Nothing) state
    go state (Tuple _ prev) = Tuple prev (Just $ render actions state)
    write (Tuple prev next) = patch api target prev next

getMachines = do
  res <- Ajax.get "/api/v1/machines"
  case decodeJson res.response :: Either String (Array Machine) of
    Left err -> pure []
    Right machines -> pure machines

main = do
  doc <- pure <<< htmlDocumentToParentNode =<< document =<< window
  target <- map elementToNode <<< toMaybe <$> querySelector "#app" doc
  actions <- channel Noop

  launchAff do
    machines <- getMachines
    liftEff $ logRaw machines
    liftEff $ send actions $ Load machines

  let state = foldp update init $ subscribe actions
  maybe (log "No div#app found!") (app state actions) target
