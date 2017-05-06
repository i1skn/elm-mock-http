module MockHttp
    exposing
        ( Request
        , Config
        , Endpoint(..)
        , EndpointData
        , config
        , get
        , getString
        , post
        , send
        , getResult
          --todo: don't expose
        )

{-|
A client-side server to simulate server-side communications that are made
through `elm-lang/Http`.

# Configure Endpoints
@docs Config, Endpoint, EndpointData, config

# Send Requests
@docs Request, send, getResult

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


requestUrl : Request a -> String
requestUrl request =
    case request of
        GetJson url _ ->
            url

        PostJson url _ _ ->
            url


requestUrlAndDecoder : Request a -> ( String, Decode.Decoder a )
requestUrlAndDecoder request =
    case request of
        GetJson url decoder ->
            ( url, decoder )

        PostJson url _ decoder ->
            ( url, decoder )


{-| configuration for endpoints.
-}
type Config
    = Config (List Endpoint)


{-| Represents an endpoint.
-}
type Endpoint
    = Get EndpointData
    | Post EndpointData


{-| Represents the details of an endpoint
-}
type alias EndpointData =
    { url : String
    , response : String
    , responseTime : Time
    }


getEndpointData : Endpoint -> EndpointData
getEndpointData endpoint =
    case endpoint of
        Get endpointData ->
            endpointData

        Post endpointData ->
            endpointData


getResponseTime : Maybe Endpoint -> Time
getResponseTime maybeEndpoint =
    case maybeEndpoint of
        Just endpoint ->
            let
                endpointData =
                    getEndpointData endpoint
            in
                endpointData.responseTime

        Nothing ->
            0


getEndpoint : Config -> Request a -> Maybe Endpoint
getEndpoint config request =
    let
        url =
            requestUrl request

        filterByEndpointType =
            getEndpointFilter request
    in
        case config of
            Config endpoints ->
                endpoints
                    |> List.filter filterByEndpointType
                    |> List.filter (filterEndpointsByUrl url)
                    |> List.head


getEndpointFilter : Request a -> (Endpoint -> Bool)
getEndpointFilter request =
    case request of
        GetJson _ _ ->
            filterByGet

        PostJson _ _ _ ->
            filterByPost


getEndpointByUrl : Config -> String -> Maybe Endpoint
getEndpointByUrl config url =
    case config of
        Config endpoints ->
            endpoints
                |> List.filter (filterEndpointsByUrl url)
                |> List.head


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
        ( result, responseTime ) =
            getResult config request
    in
        setTimeout responseTime (resultToMessage result)


{-| Get response and response time from a `Request` using configured endpoints.
-}
getResult : Config -> Request a -> ( Result Http.Error a, Time )
getResult config request =
    let
        ( url, resultDecoder ) =
            requestUrlAndDecoder request

        endpoint =
            getEndpoint config request

        responseTime =
            getResponseTime endpoint

        response =
            getResponseFromEndpointUrlAndDecoder endpoint url resultDecoder
    in
        ( response, responseTime )


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
        endpointData =
            getEndpointData endpoint

        decodeResult =
            Decode.decodeString resultDecoder endpointData.response
    in
        case decodeResult of
            Ok value ->
                Ok value

            Err decodeErr ->
                Err (badPayload decodeErr endpointData.url endpointData.response)


badPayload : String -> String -> String -> Http.Error
badPayload decoderError url response =
    Http.BadPayload decoderError (getHttpResponse url response)


getHttpResponse : String -> String -> Http.Response String
getHttpResponse url response =
    (Http.Response url { code = 200, message = "Ok" } Dict.empty response)


setTimeout : Time -> msg -> Cmd msg
setTimeout time msg =
    Process.sleep time
        |> Task.andThen (always <| Task.succeed msg)
        |> Task.perform identity
