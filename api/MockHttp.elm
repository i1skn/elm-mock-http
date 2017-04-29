module MockHttp exposing (..)


type alias Error =
    Http.Error


type Request a
    = GetJson String (Decode.Decoder a)


type Config
    = Config (List Endpoint)


type Endpoint
    = Get { url : String, response : String }


get : String -> Decode.Decoder a -> Request a


send : List Config -> (Result Http.Error a -> msg) -> Request a -> Cmd msg



--internal


setTimeout : Time -> msg -> Cmd msg


config :
    { endpoints : List Endpoint
    }
    -> Config
