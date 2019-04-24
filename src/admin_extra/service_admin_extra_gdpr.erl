-module(service_admin_extra_gdpr).

-include("ejabberd_commands.hrl").

-export(
    [commands/0,
     retrieve_all/3]).

-spec commands() -> [ejabberd_commands:cmd()].
commands() -> [
    #ejabberd_commands{name = retrieve_personal_data, tags = [gdpr],
                       desc = "Retrieve user's presonal data.",
                       longdesc = "Retrieves all personal data from MongooseIM for a given user. Example:\n"
                       " %TODO ", % TODO add example
                       module = ?MODULE,
                       function = retrieve_all,
                       args = [{username, binary}, {domain, binary}, {path, binary}], % TODO add arguments if needed
                       result = {content, binary}}  % TODO check if returned type is correct and convinient in use
].

-spec retrieve_all(gdpr:username(), gdpr:domain(), Path :: binary()) -> RetrievedFilesInZipName :: binary() | {error, Reason :: any()}.
retrieve_all(Username, Domain, ResultFilePath) ->
    case user_exists(Username, Domain) of
    true ->
        DataFromTables = get_data_from_tables(Username, Domain),
        CsvFiles = lists:map(
            fun({Tablename, Schema, Entitis}) ->
                BinTablename = atom_to_binary(Tablename, utf8),
                to_csv_file(<<BinTablename/binary, <<".csv">>/binary>>, Schema, Entitis) end,
            DataFromTables),
        {ok, R} = zip:create(ResultFilePath, lists:map(fun binary_to_list/1, CsvFiles)),
        R;
    false -> {error, "User does not exist"}
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                       Private funs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec get_data_from_tables(gdpr:username(), gdpr:domain()) ->
    [{gdpr:binary_table_name(), gdpr:schema(), gdpr:entities()}].
get_data_from_tables(Username, Domain) ->
    Modules = get_modules(),
    Tables = lists:flatten(
        [try_get_data_from_table( M, Username, Domain)|| M <- Modules]
    ),
    lists:filter(
        fun(no_table) -> false;
            (_) -> true end,
        Tables).

try_get_data_from_table(Module, Username, Domain) ->
    try Module:get_personal_data(Username, Domain) of
        [{_, _, []}] ->
            no_table;
        Val ->
            Val
    catch
        _:_ ->
            no_table
    end.

-spec to_csv_file(CsvFilename :: binary(), gdpr:schema(), gdpr:entities()) -> CsvFilename :: binary().
to_csv_file(Filename, DataSchema, DataRows) ->
    {ok, File} = file:open(Filename, [write]),
    csv_gen:row(File, DataSchema),
    lists:foreach(fun(Row) -> csv_gen:row(File, Row) end, DataRows),
    file:close(File),
    Filename.

-spec get_modules() -> [module()].
get_modules() ->
    [mod_vcard_riak,
     mod_vcard_mnesia,
     mod_vcard_rdbms,
     mod_roster].

-spec user_exists(gdpr:username(), gdpr:domain()) -> boolean().
user_exists(Username, Domain) ->
    ejabberd_auth:is_user_exists(Username, Domain).
