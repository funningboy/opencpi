library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
library ocpi; use ocpi.all; use ocpi.types.all; use ocpi.wci.all;

entity decoder is
  generic (
      worker                 : worker_t;
      properties             : properties_t);
  port (
      ocp_in                 : in in_t;       
      done                   : in bool_t := btrue;
      error                  : in bool_t := bfalse;
      resp                   : out ocp.SResp_t;
      write_enables          : out bool_array_t(properties'range);
      read_enables           : out bool_array_t(properties'range);
      offsets                : out offset_a_t(properties'range);
      indices                : out offset_a_t(properties'range);
      hi32                   : out bool_t;
      nbytes_1               : out byte_offset_t;
      data_outputs           : out data_a_t(properties'range);
      control_op             : out control_op_t;
      state                  : out state_t;
      is_operating           : out bool_t;  -- just a convenience for state = operating_e
      abort_control_op       : out bool_t;
      is_big_endian          : out bool_t   -- for runtime dynamic endian
      );
end entity;

architecture rtl of decoder is
  -- State for decoded accesses
  signal my_access       : access_t;     -- combi or register as appropriate
  signal my_access_r     : access_t;     -- registered access in progress when not immediate
  signal is_read         : bool_t;
  signal is_write        : bool_t;
  -- State for control ops
  signal control_op_in   : control_op_t; -- combi input decode
  signal my_control_op   : control_op_t; -- combi or register as appropriate
  signal my_control_op_r : control_op_t; -- registered op when not immediately finished
  -- State for write data
  signal my_data         : word_t;       -- combi or register as appropriate
  signal my_data_r       : word_t;       -- registered data when delayed
  -- state for access qualifiers for config read or write
  signal my_nbytes_1     : byte_offset_t;
  signal my_nbytes_1_r   : byte_offset_t;
  signal offset_in       : unsigned (worker.decode_width -1 downto 0);
  signal my_offset       : unsigned (worker.decode_width -1 downto 0);
  signal my_offset_r     : unsigned (worker.decode_width -1 downto 0);
  signal my_hi32         : bool_t;
  signal my_hi32_r       : bool_t;

  signal my_write_enables, my_read_enables : bool_array_t(properties'range);
  type my_offset_a_t is array(properties'range) of unsigned (worker.decode_width -1 downto 0);
  signal my_offsets      : my_offset_a_t;
  signal my_state_r      : state_t;
  signal my_reset        : Bool_t;      -- positive logic version
  signal my_error        : Bool_t;      -- immediate error detected here (not from worker)
  signal next_op         : std_logic;
  signal ok_op           : std_logic;
  signal state_pos       : natural;
  signal op_pos          : natural;
  -- convert state enum value to state number
  -- because at least isim is broken and does not implement the "pos" function
  function get_state_pos(input: state_t) return natural is
  begin
    case input is
      when exists_e => return 0;
      when initialized_e => return 1;
      when operating_e => return 2;
      when suspended_e => return 3;
      when unusable_e => return 4;
    end case;
  end get_state_pos;
  -- convert control op enum value to a number
  -- because at least isim is broken and does not implement the "pos" function
  function get_op_pos(input: control_op_t) return natural is
  begin
    case input is
      when initialize_e   => return 0;
      when start_e        => return 1;
      when stop_e         => return 2;
      when release_e      => return 3;
      when before_query_e => return 4;
      when after_config_e => return 5;
      when test_e         => return 6;
      when no_op_e        => return 7;
    end case;
  end get_op_pos;
  -- convert byte enables to low order address bytes
  function be2offset(input: in_t) return byte_offset_t is
    variable byte_en : std_logic_vector(input.MByteEn'range) := input.MByteEn; -- avoid pedantic error
  begin
    case byte_en is
      when b"0010" =>           return b"01";
      when b"0100" | b"1100" => return b"10";
      when b"1000" =>           return b"11";
      when others =>            return b"00";
    end case;
  end be2offset;
  function num_bytes_1(input : in_t) return byte_offset_t is
    variable byte_en : std_logic_vector(input.MByteEn'range) := input.MByteEn; -- avoid pedantic error
  begin
    case byte_en is
      when b"0001" | b"0010" | b"0100" | b"1000" => return b"00";
      when b"1100" | b"0011" =>                     return b"01";
      when b"1111" =>                               return b"11";                               
      when others =>                                return b"11";                               
    end case;
  end num_bytes_1;
  -- FIXME check that this synthesizes properly - may have to revert to logic...
  function any_true(bools : bool_array_t) return boolean is
    variable result: boolean := false;
  begin
    for i in bools'range loop
      if its(bools(i)) then result := true; end if;
    end loop;
    return result;
  end any_true;
begin
  -- output ports, based on internally generated signals that are also used internally
  write_enables    <= my_write_enables;
  read_enables     <= my_read_enables;
  control_op       <= my_control_op;
  state            <= my_state_r;
  is_operating     <= to_bool(my_state_r = operating_e);
  nbytes_1         <= my_nbytes_1;
  is_big_endian    <= to_bool(ocp_in.MFlag(1) = '1');
  abort_control_op <= to_bool(ocp_in.MFlag(0) = '1');
  hi32             <= my_hi32;
  -- combi signals from inputs
  offset_in        <= unsigned(ocp_in.MAddr(worker.decode_width-1 downto 2)) & be2offset(ocp_in);
  control_op_in    <= ocpi.wci.to_control_op(ocp_in.MAddr(4 downto 2));

  -- the control op to the worker is either combinatorial or registered depending
  -- on whether it is delayed by the worker
  my_control_op <= no_op_e when my_access /= control_e else
                   control_op_in when my_control_op_r = no_op_e else
                   my_control_op_r;

  -- my_access and my_data is combinatorial or registered depending on whether it is delayed
  -- by the worker
--  my_access   <= decode_access(ocp_in)          when my_access_r = none_e else my_access_r;
  my_access   <= my_access_r;
  my_data     <= ocp_in.MData                   when my_access_r = none_e else my_data_r;
  my_nbytes_1 <= num_bytes_1(ocp_in)            when my_access_r = none_e else my_nbytes_1_r;
  my_offset   <= offset_in                      when my_access_r = none_e else my_offset_r;
  my_hi32     <= to_bool(ocp_in.MAddr(2) = '1') when my_access_r = none_e else my_hi32_r;
  is_read     <= to_bool(my_access = read_e);
  is_write    <= to_bool(my_access = write_e);

  -- our own error checking (not the worker's)
  state_pos <= get_state_pos(my_state_r);
  op_pos    <= get_op_pos(my_control_op);
  next_op   <= next_ops(state_pos)(op_pos);
  ok_op     <= worker.allowed_ops(op_pos);
  my_error  <= to_bool(my_access = error_e or
                      (my_access = read_e and done and not any_true(my_read_enables)) or
                      (my_access = write_e and done and not any_true(my_write_enables)) or
                      (my_access = control_e and (ok_op = '0' or next_op = '0')));

  -- The response output is combinatorial if done or error is set.
  resp <= ocp.SResp_ERR when my_access /= none_e and (its(error) or my_error) else
          ocp.SResp_DVA when my_access /= none_e and done and not its(my_error) and not its(error) else
          ocp.SResp_NULL;

  my_reset <= not ocp_in.MReset_n;

  -- clocked processing is for delayed completion and capturing write data/addr for same
  reg: process(ocp_in.Clk) is
  begin
    -- Since we support combinatorial completion, the clocked processing
    -- deals only with longer lived commands
    if rising_edge(ocp_in.Clk) then
      -- captured request info in case response is delayed by worker
      my_data_r       <= ocp_in.MData;
      my_nbytes_1_r   <= num_bytes_1(ocp_in);
      my_offset_r     <= offset_in;
      my_hi32_r       <= to_bool(ocp_in.MAddr(2) = '1');
      my_control_op_r <= control_op_in;

      -- default value of the SResp output, which is a register
      if its(my_reset) then
        my_access_r     <= None_e;
        if worker.allowed_ops(control_op_t'pos(initialize_e)) = '1' then
          my_state_r <= exists_e;
        else
          my_state_r <= initialized_e;
        end if;
      elsif my_access = none_e then
        my_access_r <= decode_access(ocp_in);  -- delayed version until occp is fixed
      elsif its(done) or error or my_error then
        my_access_r <= none_e;
        if my_access = control_e and its(done) and not its(my_error) then
          -- successful control op - advance control state
          case my_control_op is
            when INITIALIZE_e =>
              my_state_r <= initialized_e;
            when START_e =>
              my_state_r <= operating_e;
            when STOP_e =>
              my_state_r <= suspended_e;
            when RELEASE_e =>
              my_state_r <= unusable_e;
            when others => null;                            
          end case;
        end if;
      end if;
    end if; -- rising clock
  end process;

  -- generate property instances for each property
  -- they are all combinatorial by design
  z: if properties'length > 0 generate
  gen: for i in 0 to properties'right generate -- properties'left to 0 generate
    prop: component ocpi.wci.property_decoder
      generic map (properties(i), worker.decode_width)
      port map(reset        => my_reset,
               -- inputs describing property access
               offset_in    => my_offset,
               nbytes_1     => my_nbytes_1,
               is_write     => is_write,
               is_read      => is_read,
               data_in      => my_data,
               -- outputs from the decosing process
               write_enable => my_write_enables(i),
               read_enable  => my_read_enables(i),
               offset_out   => my_offsets(i),
               index_out    => indices(i)(worker.decode_width-1 downto 0),
               data_out     => data_outputs(i));
    indices(i)(indices(i)'left downto worker.decode_width) <= (others => '0');
    offsets(i) <= resize(my_offsets(i),offsets(i)'length); -- resize to 32 bits for VHDL language reasons
  end generate gen;
  end generate z;
end rtl;

