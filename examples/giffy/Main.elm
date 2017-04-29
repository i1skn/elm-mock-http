module Main exposing (..)

import Html exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode
import Result
import Mirage exposing (Endpoint(..))
import Http


main : Program Never Model Msg
main =
    Html.program
        { init = init "cats"
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    { topic : String
    , gifUrl : String
    , errorMessage : Maybe String
    }


init : String -> ( Model, Cmd Msg )
init topic =
    ( Model topic "waiting.gif" Nothing
    , getRandomGif topic
    )



-- UPDATE


type Msg
    = MorePlease
    | NewGif (Result Http.Error String)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        MorePlease ->
            ( model, getRandomGif model.topic )

        NewGif (Ok newUrl) ->
            ( Model model.topic newUrl Nothing, Cmd.none )

        NewGif (Err error) ->
            let
                errorMessage =
                    case error of
                        Http.NetworkError ->
                            "We were unable to parse the json"

                        Http.BadUrl badUrlMessage ->
                            badUrlMessage

                        Http.BadStatus response ->
                            "Bad status"

                        Http.BadPayload decoderError response ->
                            "Bad payload" ++ decoderError

                        Http.Timeout ->
                            "Timeout"
            in
                ( { model | errorMessage = Just errorMessage }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ div []
            [ strong [] [ text "error: " ]
            , span [] [ text <| Maybe.withDefault "" model.errorMessage ]
            ]
        , h2 [] [ text model.topic ]
        , button [ onClick MorePlease ] [ text "More Please!" ]
        , br [] []
        , div [] [ text model.gifUrl ]
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- HTTP


getRandomGif : String -> Cmd Msg
getRandomGif topic =
    let
        url =
            "https://api.giphy.com/v1/gifs/random?api_key=dc6zaTOxFJmzC&tag=" ++ topic
    in
        Mirage.send config NewGif (Mirage.get url decodeGifUrl)


decodeGifUrl : Decode.Decoder String
decodeGifUrl =
    Decode.at [ "data", "image_url" ] Decode.string


config : Mirage.Config
config =
    Mirage.config
        [ Get
            { url = "https://api.giphy.com/v1/gifs/random?api_key=dc6zaTOxFJmzC&tag=cats"
            , response = "{\"data\":{ \"image_url\": \"image.png\"}}"
            }
        ]
