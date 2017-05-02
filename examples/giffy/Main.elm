module Main exposing (..)

import Html exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode
import Result
import MockHttp exposing (Endpoint(..))
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
                            "Sorry, we were unable to decode the json response."

                        Http.BadUrl badUrlMessage ->
                            badUrlMessage

                        _ ->
                            "Unknown error occurred"
            in
                ( { model | errorMessage = Just errorMessage }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ errorMessage model
        , h2 [] [ text model.topic ]
        , button [ onClick MorePlease ] [ text "More Please!" ]
        , br [] []
        , div [] [ text model.gifUrl ]
        ]


errorMessage model =
    case model.errorMessage of
        Just errorMessage ->
            div []
                [ strong [] [ text "Error message: " ]
                , span [] [ text errorMessage ]
                ]

        Nothing ->
            div [] []



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
        MockHttp.send config NewGif (MockHttp.get url decodeGifUrl)


decodeGifUrl : Decode.Decoder String
decodeGifUrl =
    Decode.at [ "data", "image_url" ] Decode.string


config : MockHttp.Config
config =
    MockHttp.config
        [ Get
            { url = "https://api.giphy.com/v1/gifs/random?api_key=dc6zaTOxFJmzC&tag=cats"
            , response = "{\"data\":{ \"image_url\": \"image.png\"}}"
            }
        ]
