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

port module Main exposing (..)

import Tests
import Test.Runner.Node exposing (run, TestProgram)
import Json.Encode exposing (Value)


main : TestProgram
main =
    run emit Tests.all


port emit : ( String, Value ) -> Cmd msg
