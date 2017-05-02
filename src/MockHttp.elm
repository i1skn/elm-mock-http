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
through `elm-lang/Http`.

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


{-| Represents an endpoint.
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

```elm
    import MockHttp
    import Json.Decode exposing (list, string)

    getSpells: MockHttp.Request (List String)
    getSpells =
        MockHttp.get "http://example.com/harrypotter/spells" (list string)
```

Compare to `Http.get`
-}
get : String -> Decode.Decoder a -> Request a
get url resultDecoder =
    GetJson url resultDecoder


{-| Create a `GET` request and interpret the response as a string.

```elm
    import MockHttp

    getBestHarryPotterCharactersName: MockHttp.Request (String)
    getBestHarryPotterCharactersName =
        MockHttp.getString "http://example.com/harrypotter/bestCharacter"
```

Compare to `Http.getString`
-}
getString : String -> Request String
getString url =
    get url string


{-| Create a POST request and try to decode the response body from JSON to an Elm value.

```elm
    import MockHttp

    disarmOtherWizard: MockHttp.Request (String)
    disarmOtherWizard =
        let
            body =
                Http.multipartBody
                    [ stringPart "spell" "expelliarmus"
                    ]
        in
            MockHttp.post "http://example.com/harrypotter/castSpell" body string
```

Compare to `Http.post`
-}
post : String -> Http.Body -> Decode.Decoder a -> Request a
post url body resultDecoder =
    PostJson url body resultDecoder


{-| Send a `Request`. We could get the main characters of "Harry Potter" like this:
```elm
import Http
import Json.Decode exposing (list, string)
import MockHttp exposing (Endpoint(..))

type Msg = Click | ReceiveCharacters (Result Http.Error (List String))

update : Msg -> Model -> Model
update msg model =
    case msg of
        Click ->
            ( model, getHarryPotterCharacters )

        ReceiveCharacters (Ok characters) ->
            ...

        ReceiveCharacters (Err _) ->
            ...

getHarryPotterCharacters : Cmd Msg
getHarryPotterCharacters =
    MockHttp.send config ReceiveCharacters <|
        MockHttp.get "https://example.com/harrypotter/characters" (list string)

config : MockHttp.Config
config =
    let
        endpoints =
            [ Get
                { url = "https://example.com/harrypotter/characters"
                , response = """
                    [ "Harry James Potter"
                    , "Ronald Bilius Weasley",
                    , "Hermione Jean Granger"
                    ]
                """
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
                getResponseFromEndpointUrlAndDecoder endpoint url resultDecoder

        PostJson url _ resultDecoder ->
            let
                endpoint =
                    getEndpoint config filterByPost request
            in
                getResponseFromEndpointUrlAndDecoder endpoint url resultDecoder


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


getResponseFromEndpointUrlAndDecoder : Maybe Endpoint -> String -> Decode.Decoder a -> Result Http.Error a
getResponseFromEndpointUrlAndDecoder endpoint url resultDecoder =
    case endpoint of
        Just endpoint ->
            decodeEndpointResult resultDecoder endpoint

        Nothing ->
            Err (Http.BadUrl ("Could not find an mock endpoint for: " ++ url))


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
