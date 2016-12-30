module Main where

import Prelude
import Network.HTTP.Affjax as Ajax
import Text.Smolder.HTML as H
import Text.Smolder.HTML.Attributes as A
import Text.Smolder.Renderer.VDOM as VDOM
import Control.Monad.Aff (launchAff)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Eff.Console (CONSOLE, log)
import Control.Monad.Eff.Exception (EXCEPTION)
import DOM (DOM)
import DOM.Node.Types (Node)
import Data.Argonaut (class DecodeJson, decodeJson)
import Data.Argonaut.Decode.Combinators ((.?))
import Data.Either (Either(Right, Left))
import Data.Maybe (Maybe(Just, Nothing))
import Data.Nullable (Nullable, toMaybe)
import Data.Traversable (for_)
import Data.Tuple (Tuple(..))
import Data.VirtualDOM (patch)
import Data.VirtualDOM.DOM (api)
import Network.HTTP.Affjax (AJAX)
import Signal (foldp, runSignal, (~>))
import Signal.Channel (CHANNEL, Channel, channel, send, subscribe)
import Text.Smolder.Markup (MarkupM, on, text, (!), (#!))
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

data Action = Init | Wake String
-----------------------------------------------

foreign import logRaw :: forall a e. a -> Eff (console :: CONSOLE | e) Unit
foreign import select :: forall e. String -> Eff (dom :: DOM | e) (Nullable Node)

view :: forall ev e.
  Channel State
  -> State
  -> MarkupM (ev -> Eff (channel :: CHANNEL, ajax :: AJAX, err :: EXCEPTION | e) Unit) Unit
view actions state = H.div ! A.className "sans-serif px4 py2 max-width-2" $ do
  H.h1 $ text "Machines"
  H.ul ! A.className "list-reset" $ do
    for_ state $ \(Machine m) ->
      H.li ! A.className "clearfix" $ do
        H.div ! A.className "machine p1 mb1 bg-white border cursor-pointer col col-8" $ do
          text $ m.name
          H.small $ text $ " (" <> m.ip <> ")"
          status m.up
        H.div ! A.className "col col-4" $ do
          H.button #! on "click" (\_ -> delete actions m.ip) $ text "Remove"
          H.button #! on "click" (\_ -> wake actions m.ip) $ text "Wake"

  where
    status true = H.i ! A.className "fa fa-check right fg-green" $ text ""
    status false = H.i ! A.className "fa fa-times right fg-red" $ text ""


main = do
  target <- toMaybe <$> select "#app"
  state :: Channel State <- channel []

  case target of
    Nothing -> log "No div#app found!"
    Just node -> do
      runSignal $ (foldp (update state) init (subscribe state)) ~> (render node)

  load state

  where
    init = (Tuple Nothing Nothing)
    update chan state (Tuple _ prev) = Tuple prev (VDOM.render $ view chan state)
    render target (Tuple prev next) = patch api target prev next


load :: forall e.
  Channel (Array Machine)
  -> Eff (err :: EXCEPTION , ajax :: AJAX , channel :: CHANNEL | e) Unit
load state = void $ launchAff do
  resp <- Ajax.get "/api/v1/machines"
  case decodeJson resp.response :: Either String (Array Machine) of
    Left err -> pure unit
    Right machines -> liftEff $ send state machines


wake :: forall e.
  Channel State
  -> String
  -> Eff (channel :: CHANNEL, ajax :: AJAX, err :: EXCEPTION | e) Unit
wake state ip = void $ launchAff do
  resp <- Ajax.patch ("/api/v1/machines/" <> ip) ""
  case decodeJson resp.response :: Either String (Array Machine) of
    Left err -> pure unit
    Right machines -> liftEff $ send state machines


delete :: forall e.
  Channel State
  -> String
  -> Eff (channel :: CHANNEL, ajax :: AJAX, err :: EXCEPTION | e) Unit
delete state ip = void $ launchAff do
  resp <- Ajax.delete ("/api/v1/machines/" <> ip)
  case decodeJson resp.response :: Either String (Array Machine) of
    Left err -> pure unit
    Right machines -> liftEff $ send state machines
