module Mirage
    exposing
        ( Request
        , Config
        , Endpoint(..)
        , config
        , get
        , getString
        , send
        , getResponse
          --todo: don't expose
        )

{-|
A client-side server to simulate server-side communications for your Elm
application.

# Configure Endpoints
@docs Config, Endpoint, config

# Send Requests
@docs Request, send, getResponse

# GET
@docs get, getString
-}

import Task
import Http
import Time exposing (Time)
import Json.Decode as Decode exposing (string)
import Dict
import Process


{-| Describes a request.
-}
type Request a
    = GetJson String (Decode.Decoder a)


{-| configuration for endpoints.
-}
type Config
    = Config (List Endpoint)


{-| Represents an endpoint with it's action, url, and response.
-}
type Endpoint
    = Get
        { url : String
        , response : String
        , responseTime : Time
        }
    | Post
        { url : String
        , response : String
        , responseTime : Time
        }


type alias EndpointFoo =
    { url : String
    , response : String
    , responseTime : Time
    }


{-| Create a `Config` from endpoints.
-}
config : List Endpoint -> Config
config endpoints =
    Config endpoints


{-| Create a `GET` request and try to decode the response body from JSON to some Elm value.

Compare to `Http.get`
-}
get : String -> Decode.Decoder a -> Request a
get url resultDecoder =
    GetJson url resultDecoder


{-| Create a `GET` request and interpret the response as a string.

Compare to `Http.getString`
-}
getString : String -> Request String
getString url =
    get url string


{-| Send a `Request`. We could get the text of "War and Peace" like this:
```elm
import Mirage exposing (Endpoint(..))
import Json.Decode exposing (string)
import Http

type Msg = Click | NewBook (Result Http.Error String)

update : Msg -> Model -> Model
update msg model =
    case msg of
        Click ->
            ( model, getWarAndPeace )

        NewBook (Ok book) ->
            ...

        NewBook (Err _) ->
            ...

getWarAndPeace : Cmd Msg
getWarAndPeace =
    Mirage.send config NewBook <|
        Mirage.getString "https://example.com/books/war-and-peace"

config : Mirage.Config
config =
    let
        endpoints =
            [ Get
                { url = "https://example.com/books/war-and-peace"
                , response = "War and Peace Text Contents"
                }
            ]
    in
        Mirage.config endpoints
```

Compare to `Http.send`.
-}
send : Config -> (Result Http.Error a -> msg) -> Request a -> Cmd msg
send config resultToMessage request =
    let
        endpoint =
            getEndpoint config request

        response =
            getResponse config request

        responseTime =
            getResponseTime endpoint
    in
        setTimeout responseTime (resultToMessage response)


getEndpoint : Config -> Request a -> Maybe Endpoint
getEndpoint config request =
    let
        url =
            case request of
                GetJson url _ ->
                    url
    in
        getEndpointByUrl config url


getEndpointByUrl : Config -> String -> Maybe Endpoint
getEndpointByUrl config url =
    case config of
        Config endpoints ->
            endpoints
                |> List.filter (endpointMatch url)
                |> List.head


getResponseTime : Maybe Endpoint -> Time
getResponseTime endpoint =
    case endpoint of
        Just endpoint ->
            case endpoint of
                Get endpoint ->
                    endpoint.responseTime

                Post endpoint ->
                    endpoint.responseTime

        Nothing ->
            0


{-| Get response from a `Request` using configured endpoints.
-}
getResponse : Config -> Request a -> Result Http.Error a
getResponse config request =
    case request of
        GetJson url resultDecoder ->
            let
                endpoint =
                    getEndpoint config request
            in
                case endpoint of
                    Just endpoint ->
                        decodeEndpointResult resultDecoder endpoint

                    Nothing ->
                        Err (Http.BadUrl ("Could not find an mock endpoint for: " ++ url))


endpointMatch : String -> Endpoint -> Bool
endpointMatch urlToMatch endpoint =
    case endpoint of
        Get endpoint ->
            endpoint.url == urlToMatch

        Post endpoint ->
            endpoint.url == urlToMatch


decodeEndpointResult : Decode.Decoder a -> Endpoint -> Result Http.Error a
decodeEndpointResult resultDecoder endpoint =
    let
        endpointValue =
            case endpoint of
                Get endpoint ->
                    endpoint

                Post endpoint ->
                    endpoint
    in
        case Decode.decodeString resultDecoder endpointValue.response of
            Ok value ->
                Ok value

            Err decodeErr ->
                Err (badPayload decodeErr endpointValue.url endpointValue.response)


badPayload : String -> String -> String -> Http.Error
badPayload decoderError url response =
    Http.BadPayload decoderError
        (Http.Response url { code = 200, message = "Ok" } Dict.empty response)


setTimeout : Time -> msg -> Cmd msg
setTimeout time msg =
    Process.sleep time
        |> Task.andThen (always <| Task.succeed msg)
        |> Task.perform identity
