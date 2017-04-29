module Mirage
    exposing
        ( Request(..)
        , Config
        , Endpoint(..)
        , get
        , send
        , config
        )

import Process
import Task
import Http
import Time exposing (Time)
import Json.Decode as Decode
import Dict


type Request a
    = GetJson String (Decode.Decoder a)


type Config
    = Config (List Endpoint)


type Endpoint
    = Get { url : String, response : String }


get : String -> Decode.Decoder a -> Request a
get url resultDecoder =
    GetJson url resultDecoder


send : Config -> (Result Http.Error a -> msg) -> Request a -> Cmd msg
send config resultToMessage request =
    case request of
        GetJson url resultDecoder ->
            let
                endpointMatch urlToMatch endpoint =
                    case endpoint of
                        Get endpointx ->
                            endpointx.url == urlToMatch

                endpoint =
                    case config of
                        Config endpoints ->
                            endpoints
                                |> List.filter (endpointMatch url)
                                |> List.head

                result =
                    case endpoint of
                        Just (Get endpoint) ->
                            case Decode.decodeString resultDecoder endpoint.response of
                                Ok value ->
                                    Ok value

                                Err decodeErr ->
                                    Err <| badPayload decodeErr url endpoint.response

                        Nothing ->
                            Err <| Http.BadUrl <| "Could not find an mock endpoint for: " ++ url
            in
                setTimeout 1000 (resultToMessage <| result)


badPayload : String -> String -> String -> Http.Error
badPayload decoderError url response =
    Http.BadPayload decoderError
        (Http.Response url { code = 200, message = "Ok" } Dict.empty response)


setTimeout : Time -> msg -> Cmd msg
setTimeout time msg =
    Process.sleep time
        |> Task.andThen (always <| Task.succeed msg)
        |> Task.perform identity


config : List Endpoint -> Config
config endpoints =
    Config endpoints
