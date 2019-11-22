module Homepage.Update exposing (subscriptions, update)

import Components.UserSearch
import GitHub.Model
import Homepage.Message
import Homepage.Model exposing (sourceHistoryLens)
import LocalStorage
import Message exposing (Msg)
import Model exposing (Model, homepageLens)
import Monocle.Lens as Lens exposing (Lens)
import Util exposing (push, wrapCmd, wrapModel)


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Components.UserSearch.subscriptions model.homepage.search
            |> Sub.map (Message.HomepageMsg << Homepage.Message.UserSearchMsg)
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Message.HomepageMsg msg2 ->
            case msg2 of
                Homepage.Message.UserSearchMsg (Components.UserSearch.HttpFetch cmd) ->
                    ( model
                    , model.authorization
                        |> cmd
                        |> Cmd.map (Message.HomepageMsg << Homepage.Message.UserSearchMsg)
                    )

                Homepage.Message.UserSearchMsg msg3 ->
                    let
                        ( model2, cmd ) =
                            Components.UserSearch.update msg3 model.homepage.search
                                |> wrapCmd (Message.HomepageMsg << Homepage.Message.UserSearchMsg)
                                |> wrapModel homepageSearchLens model
                    in
                    ( model2, cmd )

                Homepage.Message.NoOp ->
                    ( model, Cmd.none )

                Homepage.Message.SourceSelectedEvent source ->
                    let
                        model2 =
                            model
                                |> appendIfDistinct source (Lens.compose homepageLens sourceHistoryLens)
                                |> resultsLens.set []
                    in
                    ( model2
                    , Cmd.batch
                        [ push (Message.ChangeEventSourceCommand source)
                        , push (Message.HomepageMsg <| Homepage.Message.UserSearchMsg <| Components.UserSearch.Clear)
                        , LocalStorage.saveToLocalStorage model2
                        ]
                    )

                Homepage.Message.RemoveSourceCommand source ->
                    let
                        model2 =
                            model
                                |> removeFromList source (Lens.compose homepageLens sourceHistoryLens)
                    in
                    ( model2
                    , LocalStorage.saveToLocalStorage model2
                    )

        _ ->
            ( model, Cmd.none )


homepageSearchLens : Lens Model Components.UserSearch.Model
homepageSearchLens =
    Lens.compose Model.homepageLens Homepage.Model.searchLens


resultsLens : Lens Model (List GitHub.Model.GitHubUserRef)
resultsLens =
    Lens.compose homepageSearchLens Components.UserSearch.resultsLens


appendDistinctToList : a -> List a -> List a
appendDistinctToList a list =
    case list of
        [] ->
            a :: []

        x :: xs ->
            if a == x then
                list

            else
                x :: appendDistinctToList a xs


appendIfDistinct : a -> Lens b (List a) -> b -> b
appendIfDistinct a lens b =
    lens.get b |> appendDistinctToList a |> (\l -> lens.set l b)


removeFromList : a -> Lens b (List a) -> b -> b
removeFromList a lens b =
    lens.get b |> List.filter ((/=) a) |> (\l -> lens.set l b)
