defmodule ExXmlTest do
  use ExUnit.Case

  use ExXml
  doctest ExXml

  @process_ex_xml fn ex_xml, _ ->
    {:ok, escape_ex_xml(ex_xml)}
  end

  test "test simple ex_xml" do
    assert {:ok, _} =
             ~x(<foo something=#{{1, 1}}><bar2 something="a"/><a>2</a></foo>)raw
             |> parse_ex_xml()
  end

  test "test bad ex_xml" do
    assert {:error,
            "expected self_closing while processing closing_fragment or closing_tag or self_closing"} =
             ~x(<foo>)
  end

  test "test simple ex_xml with fragment" do
    assert {:ok, _} = ~x(
        <>
          <foo something=#{{1, 1}}>
            <bar2 something="a"/>
            <a>2</a>
          </foo>
        </>
      )
  end

  test "test simple ex_xml with module name" do
    assert {:ok, _} = ~x(
        <>
          <Foo something=#{{1, 1}}>
            <bar2 something="a"/>
            <a>2</a>
          </Foo>
        </>
      )
  end

  test "test basic scenic sub graph module" do
    assert {:ok, _} = ~x(
      <TestSubGraphComponent>
        <text>Passed in</text>
      </TestSubGraphComponent>
    )
  end

  test "test basic scenic graph with build options" do
    assert {:ok, _} = ~x(
      <font_size=#{20} translate=#{{0, 10}}>
        <text id=#{:temperature} text_align=#{:center} font_size=#{160}>Testing</text>
      </>
    )
  end

  test "test basic scenic graph with group options" do
    assert {:ok, _} = ~x(
      <>
        <font_size=#{20} translate=#{{0, 10}}>
          <text translate=#{{15, 60}} id=#{:event}>Event received</text>
          <text id=#{:temperature} text_align=#{:center} font_size=#{160}>Testing</text>
        </>
      </>
    )
  end

  test "test advanced scenic graph with group options" do
    assert {:ok, _} =
             ~x(
      <font=#{:roboto} font_size=#{24} theme=#{:dark}>
        <translate=#{{0, 20}}>
         <text translate=#{{15, 20}}>Various components</text>
         <text>Event received</text>
         <text_field width=#{240} hint="Type here" translate=#{{200, 160}}>A</text_field>
         <text_field hint=#{"Type here"}>A</text_field>
         <button id=#{:btn_crash} theme=#{:danger} t=#{{370, 0}}>Crash</button>
         <t=#{{15, 74}}>
           <translate=#{{0, 10}}>
             <button id=#{:btn_primary} theme=#{:primary}>Primary</button>
             <button id=#{:btn_success} t=#{{90, 0}} theme=#{:success}>Success</button>
             <button id=#{:btn_info} t=#{{180, 0}} theme=#{:info}>Info</button>
             <button id=#{:btn_light} t=#{{270, 0}} theme=#{:light}>Light</button>
             <button id=#{:btn_warning} t=#{{360, 0}} theme=#{:warning}>Warning</button>
             <button id=#{:btn_dark} t=#{{0, 40}} theme=#{:dark}>Dark</button>
             <button id=#{:btn_text} t=#{{90, 40}} theme=#{:text}>Text</button>
             <button id=#{:btn_danger} theme=#{:danger} t=#{{180, 40}}>Danger</button>
             <button id=#{:btn_secondary} width=#{100} t=#{{270, 40}} theme=#{:secondary}>
               Secondary
               All <text>Two</text>
             </button>
           </>
           <slider id=#{:num_slider} t=#{{0, 95}}>#{{{0, 100}, 0}}</slider>
             <checkbox id=#{:check_box} t=#{{200, 140}}>#{{"Check Box", true}}</checkbox>
             <text_field id=#{:text} width=#{240} translate=#{{200, 160}}>A</text_field>
             <text_field id=#{:password} width=#{240} translate=#{{200, 200}}>A</text_field>
             <dropdown id=#{:dropdown} translate=#{{0, 202}}>
               #{
               {
                 [{"Choice 1", :choice_1}, {"Choice 2", :choice_2}, {"Choice 3", :choice_3}],
                 :choice_1
               }
             }
             </dropdown>
         </>
       </>
     </>
    )
  end

  # From http://buildwithreact.com/tutorial/jsx
  test "react test" do
    game_scores = %{
      player1: 2,
      player2: 5
    }

    assert {:ok, _} = ~x(
      <>
        <div class_name="red">Children Text</div>
        <MyCounter count=#{3 + 5} />
        <DashboardUnit data_index="2">
          <h1>Scores</h1>
          <Scoreboard class_name="results" scores=#{game_scores} />
        </DashboardUnit>
      </>
    )
  end

  # From https://github.com/tastejs/todomvc/blob/gh-pages/examples/react/js/footer.jsx
  test "more react test" do
    {:ok, clear_button} = ~x(
      <button
        class_name="clear-completed"
        on_click=#{fn _ -> nil end}>
        Clear completed
      </button>
    )

    now_showing = "ALL_TODOS"
    count = 5
    active_todo_word = if count > 1, do: "items", else: "item"

    assert {:ok, _} = ~x(
      <footer class_name="footer">
        <span class_name="todo-count">
        <strong>#{count}</strong> #{active_todo_word} left
          </span>
        <ul class_name="filters">
        <li>
        <a
          href="#/"
          class_name=#{if now_showing === "ALL_TODOS", do: "selected", else: nil}>
            All
          </a>
        </li>
        #{" "}
        <li>
        <a
          href="#/active"
          class_name=#{if now_showing === "ACTIVE_TODOS", do: "selected", else: nil}>
          Active
        </a>
        </li>
          #{" "}
        <li>
        <a
          href="#/completed"
          class_name=#{if now_showing === "COMPLETED_TODOS", do: "selected", else: nil}>
            Completed
          </a>
        </li>
        </ul>
        #{clear_button}
      </footer>
    )
  end
end
