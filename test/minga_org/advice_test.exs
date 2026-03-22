defmodule MingaOrg.AdviceTest do
  use ExUnit.Case, async: true

  alias MingaOrg.Advice

  describe "advice_definitions/0" do
    test "returns around and after definitions" do
      defs = Advice.advice_definitions()
      phases = Enum.map(defs, &elem(&1, 0)) |> Enum.uniq()

      assert :around in phases
      assert :after in phases
    end

    test "every definition is a {phase, command, function} tuple" do
      for {phase, command, fun} <- Advice.advice_definitions() do
        assert phase in [:around, :after, :before],
               "expected valid phase, got: #{inspect(phase)}"

        assert is_atom(command), "expected atom command, got: #{inspect(command)}"
        assert is_function(fun), "expected function for #{phase} #{command}"
      end
    end

    test "around advice functions have arity 2" do
      for {phase, command, fun} <- Advice.advice_definitions(), phase == :around do
        assert is_function(fun, 2),
               "around advice for #{command} must have arity 2 (execute, state)"
      end
    end

    test "after advice functions have arity 1" do
      for {phase, command, fun} <- Advice.advice_definitions(), phase == :after do
        assert is_function(fun, 1),
               "after advice for #{command} must have arity 1 (state)"
      end
    end

    test "insert_newline has around advice for smart list continuation" do
      around_commands =
        Advice.advice_definitions()
        |> Enum.filter(fn {phase, _cmd, _fun} -> phase == :around end)
        |> Enum.map(&elem(&1, 1))

      assert :insert_newline in around_commands
    end

    test "cursor movement commands have after advice for decoration refresh" do
      after_commands =
        Advice.advice_definitions()
        |> Enum.filter(fn {phase, _cmd, _fun} -> phase == :after end)
        |> Enum.map(&elem(&1, 1))
        |> Enum.uniq()

      for cmd <- [:move_up, :move_down, :move_left, :move_right, :insert_newline] do
        assert cmd in after_commands, "expected after advice for #{cmd}"
      end
    end
  end
end
