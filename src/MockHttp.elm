module MockHttp
    exposing
        ( Request
        , Config
        , Endpoint(..)
        , config
        , get
        , getString
        , post
        , send
        , getResponse
          --todo: don't expose
        )

{-|
A client-side server to simulate server-side communications that are made
through `elm-lang/Http`

# Configure Endpoints
@docs Config, Endpoint, config

# Send Requests
@docs Request, send, getResponse

# GET
@docs get, getString

# POST
@docs post
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
    | PostJson String Http.Body (Decode.Decoder a)


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


{-| Create a POST request and try to decode the response body from JSON to an Elm value.

Compare to `Http.post`
-}
post : String -> Http.Body -> Decode.Decoder a -> Request a
post url body resultDecoder =
    PostJson url body resultDecoder


{-| Send a `Request`. We could get the text of "War and Peace" like this:
```elm
import MockHttp exposing (Endpoint(..))
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
    MockHttp.send config NewBook <|
        MockHttp.getString "https://example.com/books/war-and-peace"

config : MockHttp.Config
config =
    let
        endpoints =
            [ Get
                { url = "https://example.com/books/war-and-peace"
                , response = "War and Peace Text Contents"
                }
            ]
    in
        MockHttp.config endpoints
```

Compare to `Http.send`.
-}
send : Config -> (Result Http.Error a -> msg) -> Request a -> Cmd msg
send config resultToMessage request =
    let
        endpointFilter =
            case request of
                GetJson _ _ ->
                    filterByGet

                PostJson _ _ _ ->
                    filterByPost

        endpoint =
            getEndpoint config endpointFilter request

        response =
            getResponse config request

        responseTime =
            getResponseTime endpoint
    in
        setTimeout responseTime (resultToMessage response)


getEndpoint : Config -> (Endpoint -> Bool) -> Request a -> Maybe Endpoint
getEndpoint config filterByEndpointType request =
    let
        url =
            case request of
                GetJson url _ ->
                    url

                PostJson url _ _ ->
                    url
    in
        case config of
            Config endpoints ->
                endpoints
                    |> List.filter filterByEndpointType
                    |> List.filter (filterEndpointsByUrl url)
                    |> List.head


getEndpointByUrl : Config -> String -> Maybe Endpoint
getEndpointByUrl config url =
    case config of
        Config endpoints ->
            endpoints
                |> List.filter (filterEndpointsByUrl url)
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
                    getEndpoint config filterByGet request
            in
                case endpoint of
                    Just endpoint ->
                        decodeEndpointResult resultDecoder endpoint

                    Nothing ->
                        Err (Http.BadUrl ("Could not find an mock endpoint for: " ++ url))

        PostJson url _ resultDecoder ->
            let
                endpoint =
                    getEndpoint config filterByPost request
            in
                case endpoint of
                    Just endpoint ->
                        decodeEndpointResult resultDecoder endpoint

                    Nothing ->
                        Err (Http.BadUrl ("Could not find an mock endpoint for: " ++ url))


filterByGet : Endpoint -> Bool
filterByGet endpoint =
    case endpoint of
        Get _ ->
            True

        Post _ ->
            False


filterByPost : Endpoint -> Bool
filterByPost endpoint =
    case endpoint of
        Get _ ->
            False

        Post _ ->
            True


filterEndpointsByUrl : String -> Endpoint -> Bool
filterEndpointsByUrl urlToMatch endpoint =
    let
        url =
            case endpoint of
                Get endpoint ->
                    endpoint.url

                Post endpoint ->
                    endpoint.url
    in
        url == urlToMatch


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
