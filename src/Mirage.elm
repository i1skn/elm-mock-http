module Mirage
    exposing
        ( Config
        , Endpoint(..)
        , config
        , get
        , send
        , getResult
          --todo: don't expose
        )

{-|
Allows you to send out mock http requests with predefined responses.

@docs Config, Endpoint, config, get, send
-}

import Task
import Http
import Time exposing (Time)
import Json.Decode as Decode
import Dict
import Process


{-| Mirage configuration for endpoints.
-}
type Config
    = Config (List Endpoint)


{-| Represents an endpoint with it's action, url, and response.
-}
type Endpoint
    = Get { url : String, response : String }


{-| Create a Config.
-}
config : List Endpoint -> Config
config endpoints =
    Config endpoints


type Request a
    = GetJson String (Decode.Decoder a)


{-| get
-}
get : String -> Decode.Decoder a -> Request a
get url resultDecoder =
    GetJson url resultDecoder


{-| send
-}
send : Config -> (Result Http.Error a -> msg) -> Request a -> Cmd msg
send config resultToMessage request =
    let
        result =
            getResult config request
    in
        setTimeout 1000 (resultToMessage result)


{-| Get result of Request returned from `Mirage.get`
-}
getResult config request =
    case request of
        GetJson url resultDecoder ->
            let
                endpoint =
                    getEndpointByUrl config url
            in
                case endpoint of
                    Just endpoint ->
                        decodeEndpointResult resultDecoder endpoint

                    Nothing ->
                        Err (Http.BadUrl ("Could not find an mock endpoint for: " ++ url))


getEndpointByUrl : Config -> String -> Maybe Endpoint
getEndpointByUrl config url =
    case config of
        Config endpoints ->
            endpoints
                |> List.filter (endpointMatch url)
                |> List.head


endpointMatch : String -> Endpoint -> Bool
endpointMatch urlToMatch endpoint =
    case endpoint of
        Get endpoint ->
            endpoint.url == urlToMatch


decodeEndpointResult : Decode.Decoder a -> Endpoint -> Result Http.Error a
decodeEndpointResult resultDecoder endpoint =
    case endpoint of
        Get endpoint ->
            case Decode.decodeString resultDecoder endpoint.response of
                Ok value ->
                    Ok value

                Err decodeErr ->
                    Err (badPayload decodeErr endpoint.url endpoint.response)


badPayload : String -> String -> String -> Http.Error
badPayload decoderError url response =
    Http.BadPayload decoderError
        (Http.Response url { code = 200, message = "Ok" } Dict.empty response)


setTimeout : Time -> msg -> Cmd msg
setTimeout time msg =
    Process.sleep time
        |> Task.andThen (always <| Task.succeed msg)
        |> Task.perform identity
