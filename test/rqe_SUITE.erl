%%%-------------------------------------------------------------------
%%% @author Stefan Hagdahl <stefan.hagdah>
%%% @copyright (C) 2019, Stefan Hagdahl
%%% @doc
%%%
%%% @end
%%% Created : 30 Sep 2019 by Stefan Hagdahl <stefan.hagdahl>
%%%-------------------------------------------------------------------
-module(rqe_SUITE).

%% Note: This directive should only be used in test suites.
-compile(export_all).

-include_lib("common_test/include/ct.hrl").

%%--------------------------------------------------------------------
%% COMMON TEST CALLBACK FUNCTIONS
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% @doc
%%  Returns list of tuples to set default properties
%%  for the suite.
%%
%% Function: suite() -> Info
%%
%% Info = [tuple()]
%%   List of key/value pairs.
%%
%% Note: The suite/0 function is only meant to be used to return
%% default data values, not perform any other operations.
%%
%% @spec suite() -> Info
%% @end
%%--------------------------------------------------------------------
suite() ->
    {ok, _} = application:ensure_all_started(lager),
    %% {ok, _} = application:ensure_all_started(erqec),
    [{timetrap,{minutes,10}}].

%%--------------------------------------------------------------------
%% @doc
%% Initialization before the whole suite
%%
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%% Reason = term()
%%   The reason for skipping the suite.
%%
%% Note: This function is free to add any key/value pairs to the Config
%% variable, but should NOT alter/remove any existing entries.
%%
%% @spec init_per_suite(Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%% @end
%%--------------------------------------------------------------------
init_per_suite(Config) ->
    Config.

%%--------------------------------------------------------------------
%% @doc
%% Cleanup after the whole suite
%%
%% Config - [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%%
%% @spec end_per_suite(Config) -> _
%% @end
%%--------------------------------------------------------------------
end_per_suite(_Config) ->
    ok.

%%--------------------------------------------------------------------
%% @doc
%% Initialization before each test case group.
%%
%% GroupName = atom()
%%   Name of the test case group that is about to run.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding configuration data for the group.
%% Reason = term()
%%   The reason for skipping all test cases and subgroups in the group.
%%
%% @spec init_per_group(GroupName, Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%% @end
%%--------------------------------------------------------------------
init_per_group(_GroupName, Config) ->
    Config.

%%--------------------------------------------------------------------
%% @doc
%% Cleanup after each test case group.
%%
%% GroupName = atom()
%%   Name of the test case group that is finished.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding configuration data for the group.
%%
%% @spec end_per_group(GroupName, Config0) ->
%%               term() | {save_config,Config1}
%% @end
%%--------------------------------------------------------------------
end_per_group(_GroupName, _Config) ->
    ok.

%%--------------------------------------------------------------------
%% @doc
%% Initialization before each test case
%%
%% TestCase - atom()
%%   Name of the test case that is about to be run.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%% Reason = term()
%%   The reason for skipping the test case.
%%
%% Note: This function is free to add any key/value pairs to the Config
%% variable, but should NOT alter/remove any existing entries.
%%
%% @spec init_per_testcase(TestCase, Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%% @end
%%--------------------------------------------------------------------
init_per_testcase(_TestCase, Config) ->
    application:load(grpcbox),
    application:stop(grpcbox),
    {ok, #{protocol := Protocol,
           ip := IP,
           port := Port}} = application:get_env(erqec, grpc),
    Server = [{Protocol, IP, Port, []}],
    Channels = create_grpcbox_channels(0, Server, []),
    application:set_env(grpcbox, client,
                        #{channels => Channels}),
    {ok, _} = application:ensure_all_started(grpcbox),
    [{channels, Channels}|Config].

%%--------------------------------------------------------------------
%% @doc
%% Cleanup after each test case
%%
%% TestCase - atom()
%%   Name of the test case that is finished.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%%
%% @spec end_per_testcase(TestCase, Config0) ->
%%               term() | {save_config,Config1} | {fail,Reason}
%% @end
%%--------------------------------------------------------------------
end_per_testcase(_TestCase, _Config) ->
    ok.

%%--------------------------------------------------------------------
%% @doc
%% Returns a list of test case group definitions.
%%
%% Group = {GroupName,Properties,GroupsAndTestCases}
%% GroupName = atom()
%%   The name of the group.
%% Properties = [parallel | sequence | Shuffle | {RepeatType,N}]
%%   Group properties that may be combined.
%% GroupsAndTestCases = [Group | {group,GroupName} | TestCase]
%% TestCase = atom()
%%   The name of a test case.
%% Shuffle = shuffle | {shuffle,Seed}
%%   To get cases executed in random order.
%% Seed = {integer(),integer(),integer()}
%% RepeatType = repeat | repeat_until_all_ok | repeat_until_all_fail |
%%              repeat_until_any_ok | repeat_until_any_fail
%%   To get execution of cases repeated.
%% N = integer() | forever
%%
%% @spec: groups() -> [Group]
%% @end
%%--------------------------------------------------------------------
groups() ->
    [].

%%--------------------------------------------------------------------
%% @doc
%%  Returns the list of groups and test cases that
%%  are to be executed.
%%
%% GroupsAndTestCases = [{group,GroupName} | TestCase]
%% GroupName = atom()
%%   Name of a test case group.
%% TestCase = atom()
%%   Name of a test case.
%% Reason = term()
%%   The reason for skipping all groups and test cases.
%%
%% @spec all() -> GroupsAndTestCases | {skip,Reason}
%% @end
%%--------------------------------------------------------------------
all() ->
    [create_rqs_case, match_entry_case].


%%--------------------------------------------------------------------
%% TEST CASES
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% @doc Test case function. (The name of it must be specified in
%%              the all/0 list or in a test case group for the test case
%%              to be executed).
%%
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%% Reason = term()
%%   The reason for skipping the test case.
%% Comment = term()
%%   A comment about the test case that will be printed in the html log.
%%
%% @spec TestCase(Config0) ->
%%           ok | exit() | {skip,Reason} | {comment,Comment} |
%%           {save_config,Config1} | {skip_and_save,Reason,Config1}
%% @end
%%--------------------------------------------------------------------
create_rqs_case(Config) ->
    Channel = proplists:get_value(channel, Config, default_channel),
    RQ = [#{key => "rqe_testing", value => {string,<<"create_rqs_case">>},
            type_options => #{operator => 'NULL'}}],
    Copies = 10,
    RQIds = add_rq(RQ, Copies, Channel),
    delete_rq(RQIds, Channel),
    if
        length(RQIds) == Copies ->
            ct:pal("Successfully created RQs");
        true ->
            ct:fail("Didn't successfully create ~p but ~p RQs",
                    [Copies, length(RQIds)])
    end.

%%--------------------------------------------------------------------
%% @doc Test case function. (The name of it must be specified in
%%              the all/0 list or in a test case group for the test case
%%              to be executed).
%%
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%% Reason = term()
%%   The reason for skipping the test case.
%% Comment = term()
%%   A comment about the test case that will be printed in the html log.
%%
%% @spec TestCase(Config0) ->
%%           ok | exit() | {skip,Reason} | {comment,Comment} |
%%           {save_config,Config1} | {skip_and_save,Reason,Config1}
%% @end
%%--------------------------------------------------------------------
match_entry_case(Config) ->
    Channel = proplists:get_value(channel, Config, default_channel),
    RQ = [#{key => "rqe_testing",
            value => {string,<<"match_entry_case match">>},
            type_options => #{operator => 'NULL'}}],
    Copies = 10,
    RQIds = add_rq(RQ, Copies, Channel),
    Copies = length(RQIds),
    EntryMatch = #{<<"rqe_testing">> =>
                       #{value => {string, <<"match_entry_case match">>}}},
    EntryNoMatch = #{<<"rqe_testing">> =>
                         #{value =>
                               {string, <<"match_entry_case no match">>}}},
    RQs = match_entry(EntryMatch, Channel),
    NoRQs = match_entry(EntryNoMatch, Channel),
    delete_rq(RQIds, Channel),
    RQIdsLength = length(RQIds),
    RQIdsLength = length(match_rqs(RQIds, RQs, [])),
    [] = match_rqs(RQIds, NoRQs, []).

%%%===================================================================
%%% Internal functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
spawn_multiple_fun(Module, Function, Args, Instances) ->
    lists:map(
      fun(Instance) ->
              ChannelName = create_channel_name(Instance),
              erlang:spawn_monitor(Module, Function, Args ++ [ChannelName])
      end,
      lists:seq(1, Instances)).

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
wait_for_spawned_functions([]) ->
    ok;
wait_for_spawned_functions(Pids) ->
    receive
        {'DOWN', _, process, Pid, _Info} ->
            RemainingPids = proplists:delete(Pid, Pids),
            wait_for_spawned_functions(RemainingPids)
    end.

%%--------------------------------------------------------------------
%% @doc
%% RQ = [#{key => "erqec", value => {string,<<"is best">>},
%%       type_options => #{operator => 'NULL'}}].
%% @end
%%--------------------------------------------------------------------
add_rq(RQ, Copies, Channel) ->
    ct:pal("Creating ~p copies of RQ:~p", [Copies, RQ]),
    lists:map(
      fun(_) ->
              case erqec_api:add_rq(RQ, [], Channel) of
                  {ok, UUID} ->
                      UUID;
                  {nok, _} ->
                      []
              end
      end,
      lists:seq(1, Copies)).

%%--------------------------------------------------------------------
%% @doc
%% Delete RQs
%% @end
%%--------------------------------------------------------------------
delete_rq(RQIds, Channel) ->
    lists:foreach(
      fun(RQId) ->
              erqec_api:delete_rq(RQId, Channel)
      end,
      RQIds).

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
match_entry(Entry, Channel) ->
    Now = os:system_time(millisecond),
    {ok, RQs} = erqec_api:match_entry(Entry, Channel),
    After = os:system_time(millisecond),
    ct:pal("Received ~p RQs matches for ~p in ~pmillisecond~n",
           [length(RQs), Entry, After - Now]),
    lists:map(
      fun(#{uuid := UUID}) ->
              UUID
      end,
      RQs).

%%--------------------------------------------------------------------
%% @doc
%% Match RQs
%% @end
%%--------------------------------------------------------------------
match_rqs([], _, Matched) ->
    Matched;
match_rqs([RQId|Rest], RQs, Matched) ->
    Exists = lists:member(RQId, RQs),
    if
        Exists == true ->
            match_rqs(Rest, RQs, [RQId|Matched]);
        true ->
            ct:pal("RQId ~p missing from ~p",
                   [RQId, RQs]),
            match_rqs(Rest, RQs, Matched)
    end.

%%--------------------------------------------------------------------
%% @doc
%%
%% @end
%%--------------------------------------------------------------------
create_grpcbox_channels(0, Server, []) ->
    [{default_channel, Server, #{}}];
create_grpcbox_channels(0, _, Channels) ->
    Channels;
create_grpcbox_channels(Instances, Server, Channels) ->
    ChannelName = create_channel_name(Instances),
    Channel = {ChannelName, Server, #{}},
    create_grpcbox_channels(Instances-1, Server, [Channel|Channels]).


%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
create_channel_name(Instance) ->
     erlang:list_to_atom(lists:concat(["grpc_channel_", Instance])).
