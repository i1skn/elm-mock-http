{-
Copyright (c) 2017 Ryan Olson

GNU GENERAL PUBLIC LICENSE
    Version 3, 29 June 2007

This file is part of elm-mock-http.

elm-mock-http is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

elm-mock-http is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with elm-mock-http.  If not, see <http://www.gnu.org/licenses/>.
-}

module Tests exposing (..)

import Expect
import Http
import Json.Decode as Decode exposing (list, string)
import MockHttp exposing (Endpoint(..))
import Test exposing (..)


-- import Fuzz exposing (list, int, tuple, string)

import MockHttp exposing (Endpoint(..))
import Json.Decode as Decode exposing (list, string)
import Http


all : Test
all =
    describe "MockHttp"
        [ get
        , post
        ]


get : Test
get =
    describe "get"
        [ test "typical successful case" <|
            \() ->
                let
                    url =
                        "http://example.com/books"

                    config =
                        MockHttp.config
                            [ Get
                                { url = url
                                , response = """
                                        [ "The Lord of the Rings"
                                        , "Harry Potter"
                                        ]
                                      """
                                , responseTime = 1000
                                }
                            ]

                    getBooks =
                        MockHttp.get "http://example.com/books" (list string)

                    ( response, _ ) =
                        MockHttp.getResult config getBooks
                in
                    case response of
                        Ok books ->
                            Expect.equal [ "The Lord of the Rings", "Harry Potter" ] books

                        Err _ ->
                            Expect.fail "It should have successfully returned results."
        , test "typical successful case with multiple endpoints configured" <|
            \() ->
                let
                    url =
                        "http://example.com/books"

                    config =
                        MockHttp.config
                            [ Get
                                { url = url ++ "/classics"
                                , response = """
                                        [ "Pride and Prejudice"
                                        , "The Great Gatsby"
                                        ]
                                      """
                                , responseTime = 1000
                                }
                            , Get
                                { url = url
                                , response = """
                                        [ "The Lord of the Rings"
                                        , "Harry Potter"
                                        ]
                                      """
                                , responseTime = 1000
                                }
                            ]

                    getBooks =
                        MockHttp.get "http://example.com/books" (list string)

                    ( response, _ ) =
                        MockHttp.getResult config getBooks
                in
                    case response of
                        Ok books ->
                            Expect.equal [ "The Lord of the Rings", "Harry Potter" ] books

                        Err _ ->
                            Expect.fail "It should have successfully returned results."
        , test "url that isn't configured will give a badUrl error" <|
            \() ->
                let
                    config =
                        MockHttp.config []

                    getBooks =
                        MockHttp.get "http://example.com/books" (list string)

                    ( response, _ ) =
                        MockHttp.getResult config getBooks
                in
                    case response of
                        Err httpError ->
                            case httpError of
                                Http.BadUrl _ ->
                                    Expect.pass

                                _ ->
                                    Expect.fail "This was expected to fail with a bad url http error"

                        Ok _ ->
                            Expect.fail "This was expected to give an error."
        ]



-- , describe "Fuzz test examples, using randomly generated input"
--     [ fuzz (list int) "Lists always have positive length" <|
--         \aList ->
--             List.length aList |> Expect.atLeast 0
--     , fuzz (list int) "Sorting a list does not change its length" <|
--         \aList ->
--             List.sort aList |> List.length |> Expect.equal (List.length aList)
--     , fuzzWith { runs = 1000 } int "List.member will find an integer in a list containing it" <|
--         \i ->
--             List.member i [ i ] |> Expect.true "If you see this, List.member returned False!"
--     , fuzz2 string string "The length of a string equals the sum of its substrings' lengths" <|
--         \s1 s2 ->
--             s1 ++ s2 |> String.length |> Expect.equal (String.length s1 + String.length s2)
--     ]


post : Test
post =
    describe "post"
        [ test "typical successful case" <|
            \() ->
                let
                    url =
                        "http://example.com/books"

                    config =
                        MockHttp.config
                            [ Post
                                { url = url
                                , response = """
                                        "Saved!"
                                    """
                                , responseTime = 500
                                }
                            ]

                    saveBooks =
                        MockHttp.post "http://example.com/books" Http.emptyBody string

                    ( response, _ ) =
                        MockHttp.getResult config saveBooks
                in
                    case response of
                        Ok message ->
                            Expect.equal "Saved!" message

                        Err err ->
                            case err of
                                Http.BadUrl badUrlMessage ->
                                    Expect.fail badUrlMessage

                                Http.BadPayload decodeErrorMessage _ ->
                                    Expect.fail decodeErrorMessage

                                _ ->
                                    Expect.fail "It should have successfully saved."
        ]
