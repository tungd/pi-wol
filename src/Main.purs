module Main where

import Network.HTTP.Affjax as Ajax
import Text.Smolder.HTML as H
import Control.Monad.Aff (launchAff)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Eff.Console (CONSOLE, log)
import Control.Monad.Eff.Timer (TIMER)
import DOM (DOM)
import DOM.Node.Types (Node)
import Data.Argonaut (class DecodeJson, decodeJson)
import Data.Argonaut.Decode.Combinators ((.?))
import Data.Either (Either(Right, Left))
import Data.Foldable (sequence_)
import Data.Maybe (Maybe(..), maybe)
import Data.Nullable (Nullable, toMaybe)
import Data.Tuple (Tuple(..))
import Data.VirtualDOM (patch)
import Data.VirtualDOM.DOM (api)
import Signal (sampleOn, runSignal, (~>), foldp, Signal)
import Signal.Channel (CHANNEL, Channel, channel, send, subscribe)
import Signal.DOM (animationFrame)
import Text.Smolder.HTML.Attributes as A
import Text.Smolder.Markup ((!), (#!), text, on)
import Text.Smolder.Renderer.VDOM (render)
import Prelude hiding (div)
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
foreign import select :: forall e. String -> Eff (dom :: DOM | e) (Nullable Node)

init :: State
init = []

view actions state = H.div ! A.className "app" $ do
  H.h1 $ text "Machines"
  H.ul do
    sequence_ $ map (\(Machine m) -> H.li $ text m.ip) state

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
    go state (Tuple _ prev) = Tuple prev (render $ view actions state)
    write (Tuple prev next) = patch api target prev next

getMachines = do
  res <- Ajax.get "/api/v1/machines"
  case decodeJson res.response :: Either String (Array Machine) of
    Left err -> pure []
    Right machines -> pure machines

main = do
  target <- toMaybe <$> select "#app"
  actions <- channel Noop

  launchAff do
    machines <- getMachines
    liftEff $ send actions $ Load machines

  let state = foldp update init $ subscribe actions
  maybe (log "No div#app found!") (app state actions) target
