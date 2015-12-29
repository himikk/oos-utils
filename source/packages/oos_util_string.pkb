create or replace package body oos_util_string
as

  -- ******** PUBLIC ********

  /**
   * Converts parameter to varchar2
   *
   * Notes:
   *  - Need to call this tochar instead of to_char since there will be a conflict when calling it
   *  - Code copied from Logger: https://github.com/OraOpenSource/Logger
   *
   * Related Tickets:
   *  - #11
   *
   * @author Martin D'Souza
   * @created 07-Jun-2014
   * @param p_value
   * @return varchar2 value for p_value
   */
  function tochar(
    p_val in number)
    return varchar2
  as
  begin
    return to_char(p_val);
  end tochar;

  function tochar(
    p_val in date)
    return varchar2
  as
  begin
    return to_char(p_val, oos_util.gc_date_format);
  end tochar;

  function tochar(
    p_val in timestamp)
    return varchar2
  as
  begin
    return to_char(p_val, oos_util.gc_timestamp_format);
  end tochar;

  function tochar(
    p_val in timestamp with time zone)
    return varchar2
  as
  begin
    return to_char(p_val, oos_util.gc_timestamp_tz_format);
  end tochar;

  function tochar(
    p_val in timestamp with local time zone)
    return varchar2
  as
  begin
    return to_char(p_val, oos_util.gc_timestamp_tz_format);
  end tochar;

  function tochar(
    p_val in boolean)
    return varchar2
  as
  begin
    return case when p_val then 'TRUE' else 'FALSE' end;
  end tochar;


  /**
   * Truncates a string to ensure that it is not longer than p_length
   * If string is > than p_length then an ellipsis (...) will be appended to string
   *
   * Supports following modes:
   *  - By length (default): Will perform a hard parse at p_length
   *  - By word: Will truncate at logical word break
   *
   * Notes:
   *  -
   *
   * Related Tickets:
   *  - #5
   *
   * @author Martin D'Souza
   * @created 05-Sep-2015
   * @param TODO
   * @return Trimmed string
   */
   -- TODO mdsouza: need a better name for this
   -- TODO mdsouza: ellipsize??
  function truncate_string(
    p_str in varchar2,
    p_length in pls_integer,
    -- TODO mdsouza: do we have this called "p_options" to pass in various options?
    -- TODO mdsouza: we may have this more than just "by word"
    p_by_word in varchar2 default 'N'
    -- TODO mdsouza: have p_elipsis as a variable?
  )
    return varchar2
  as
    l_stop_position pls_integer;
    l_str varchar2(32767) := trim(p_str);
    l_ellipsis varchar2(3) := '...';
    l_by_word boolean := false;

    l_scope varchar2(255) := 'oos_util_string.truncate_string';
    l_max_length pls_integer := p_length - length(l_ellipsis); -- This is the max that the string can be without an ellipsis appended to it.
  begin
    -- TODO mdsouza: look at the cost of doing these checks
    oos_util.assert(upper(nvl(p_by_word, 'N')) in ('Y', 'N'), 'Invalid p_by_word. Must be Y/N');
    oos_util.assert(p_length > 0, 'p_length must be a postive number');

    if upper(nvl(p_by_word, 'N')) = 'Y' then
      l_by_word := true;
    end if;

    if length(l_str) <= p_length then
      l_str := l_str;
    elsif length(l_ellipsis) > p_length or l_max_length = 0 then
      -- Can't replace string with ellipsis if it'll return a larger string.
      l_str := substr(l_str, 1, p_length);
    elsif not l_by_word then
      -- Truncate by length
      l_str := trim(substr(l_str, 1, l_max_length)) || l_ellipsis;
    elsif l_by_word then
      -- If string at [max string(length) - ellipsis] and next characters belong to same word
      -- Then need to go back and find last non-word
      if regexp_instr(l_str, '\w{2,}', l_max_length, 1, 0) = l_max_length then
        l_str := substr(
            l_str,
            1,
            -- Find the last non-word and go back one character
            regexp_instr(substr(l_str,1, p_length - length(l_ellipsis)), '\W+\w*$') -1);

        if l_str is null then
          -- This will happen if the length is just slightly greater than the elipsis and first word is long
          l_str := substr(trim(p_str), 1, l_max_length);
        end if;

      else
        -- Find last non-word. Need to reverse the string since Oracle regexp doesn't support lookbehind assertions
        -- Need to do the reverse in a select statement since it's not a PL/SQL function
        with rev_str as (
          select reverse(substr(l_str,1, l_max_length)) str from sys.dual
        )
        select
          -- Unreverse string
          reverse(
            -- Cut the string from the first word char to the end in the reveresed string
            -- Since this is a reversed string, the first word char, is really the last word char
            substr(rev_str.str, regexp_instr(rev_str.str, '\w'))
          )
        into l_str
        from rev_str;

      end if;

      l_str := l_str || l_ellipsis;

      -- end l_by_word
    end if;

    return l_str;
  end truncate_string;


  /**
   * Does string replacement similar to C's sprintf
   *
   * Notes:
   *  - Uses the following replacement algorithm (in following order)
   *    - Replaces %s<n> with p_s<n>
   *    - Occurrences of %s (no number) are replaced with p_s1..p_s10 in order that they appear in text
   *    - %% is escaped to %
   *  - As this function could be useful for non-logging purposes will not apply a NO_OP to it for conditional compilation
   *
   * Related Tickets:
   *  - #8
   *
   * @author Martin D'Souza
   * @created 15-Jun-2014
   * @param p_str Messsage to format using %s and %d replacement strings
   * @param p_s1
   * @param p_s2
   * @param p_s3
   * @param p_s4
   * @param p_s5
   * @param p_s6
   * @param p_s7
   * @param p_s8
   * @param p_s9
   * @param p_s10
   * @return p_msg with strings replaced
   */
  function sprintf(
    p_str in varchar2,
    p_s1 in varchar2 default null,
    p_s2 in varchar2 default null,
    p_s3 in varchar2 default null,
    p_s4 in varchar2 default null,
    p_s5 in varchar2 default null,
    p_s6 in varchar2 default null,
    p_s7 in varchar2 default null,
    p_s8 in varchar2 default null,
    p_s9 in varchar2 default null,
    p_s10 in varchar2 default null)
    return varchar2
  as
    l_return varchar2(4000);
    c_substring_regexp constant varchar2(10) := '%s';

  begin
    l_return := p_str;

    -- Replace %s<n> with p_s<n>``
    for i in 1..10 loop
      l_return := regexp_replace(l_return, c_substring_regexp || i,
        case
          when i = 1 then p_s1
          when i = 2 then p_s2
          when i = 3 then p_s3
          when i = 4 then p_s4
          when i = 5 then p_s5
          when i = 6 then p_s6
          when i = 7 then p_s7
          when i = 8 then p_s8
          when i = 9 then p_s9
          when i = 10 then p_s10
          else null
        end,
        1,0,'c');
    end loop;

    -- Replace any occurences of %s with p_s<n> (in order) and escape %% to %
    l_return := sys.utl_lms.format_message(l_return,p_s1, p_s2, p_s3, p_s4, p_s5, p_s6, p_s7, p_s8, p_s9, p_s10);

    return l_return;

  end sprintf;


  /**
   * Converts delimited string to table
   *
   * Notes:
   *  - Text between delimiters must be <= 4000 characters
   *
   * Example:
   *  select rownum, column_value
   *  from table(oos_util_string.string_to_table('abc,def'));
   *
   * Related Tickets:
   *  - #4
   *
   * @author Martin Giffy D'Souza
   * @created 28-Dec-2015
   * @param p_string String containing delimited text
   * @param p_delimiter Delimiter
   * @return pipelined table
   */
  function string_to_table(
    p_string in varchar2,
    p_delimiter in varchar2 default ',')
    return tab_vc2 pipelined
  is
    l_temp apex_application_global.vc_arr2;
  begin
    l_temp := apex_util.string_to_table(p_string => p_string, p_separator => p_delimiter);

    for i in 1 .. l_temp.count loop
      pipe row (l_temp(i));
    end loop;
  end string_to_table;


  /**
   * Converts delimited string to table
   *
   * Notes:
   *  - Text between delimiters must be <= 4000 characters
   *
   * Example:
   *  select rownum, column_value
   *  from table(oos_util_string.string_to_table('abc,def'));
   *
   * Related Tickets:
   *  - #4
   *
   * @author Martin Giffy D'Souza
   * @created 28-Dec-2015
   * @param p_string String (clob) containing delimited text
   * @param p_delimiter Delimiter
   * @return pipelined table
   */
  function string_to_table(
    p_clob in clob,
    p_delimiter in varchar2 default ',')
    return tab_vc2 pipelined
  is
    l_occurrence pls_integer;
    l_last_pos pls_integer;
    l_pos pls_integer;
    l_length pls_integer;
  begin

    if p_clob is not null then
      l_occurrence := 1;
      l_last_pos := 0;
      l_pos := 1;
      l_length := dbms_lob.getlength(p_clob);

      while l_pos > 0 loop
        l_pos := instr(p_clob, p_delimiter, 1, l_occurrence);

        if l_pos = 0 then
          pipe row (substr(p_clob, l_last_pos + 1, l_length));
        else
          pipe row (substr(p_clob, l_last_pos + 1, l_pos - (l_last_pos+1)));
        end if; -- l_pos = 0

        l_last_pos := l_pos;
        l_occurrence := l_occurrence + 1;
      end loop;
    end if; -- p_clob is not null
  end string_to_table;

end oos_util_string;
/
