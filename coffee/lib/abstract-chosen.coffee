class AbstractChosen

  constructor: (@form_field, @options={}) ->
    return unless AbstractChosen.browser_is_supported()
    @is_multiple = @form_field.multiple
    @can_select_by_group = @form_field.getAttribute('select-by-group') isnt null
    this.set_default_text()
    this.set_default_values()

    this.setup()

    this.set_up_html()
    this.register_observers()
    # instantiation done, fire ready
    this.on_ready()

  set_default_values: ->
    @click_test_action = (evt) => this.test_active_click(evt)
    @activate_action = (evt) => this.activate_field(evt)
    @active_field = false
    @mouse_on_container = false
    @results_showing = false
    @result_highlighted = null
    @is_rtl = @options.rtl || /\bchosen-rtl\b/.test(@form_field.className)
    @allow_single_deselect = if @options.allow_single_deselect? and @form_field.options[0]? and @form_field.options[0].text is "" then @options.allow_single_deselect else false
    @disable_search_threshold = @options.disable_search_threshold || 0
    @disable_search = @options.disable_search || false
    @enable_split_word_search = if @options.enable_split_word_search? then @options.enable_split_word_search else true
    @group_search = if @options.group_search? then @options.group_search else true
    @search_in_values = @options.search_in_values || false
    @search_contains = @options.search_contains || false
    @single_backstroke_delete = if @options.single_backstroke_delete? then @options.single_backstroke_delete else true
    @max_selected_options = @options.max_selected_options || Infinity
    @inherit_select_classes = @options.inherit_select_classes || false
    @inherit_option_classes = @options.inherit_option_classes || false
    @display_selected_options = if @options.display_selected_options? then @options.display_selected_options else true
    @display_disabled_options = if @options.display_disabled_options? then @options.display_disabled_options else true
    @parser_config = @options.parser_config || {}
    @include_group_label_in_selected = @options.include_group_label_in_selected || false
    @max_shown_results = @options.max_shown_results || Number.POSITIVE_INFINITY
    @case_sensitive_search = @options.case_sensitive_search || false
    @hide_results_on_select = if @options.hide_results_on_select? then @options.hide_results_on_select else true
    @create_option = @options.create_option || false
    @persistent_create_option = @options.persistent_create_option || false
    @skip_no_results = @options.skip_no_results || false

  set_default_text: ->
    if @form_field.getAttribute("data-placeholder")
      @default_text = @form_field.getAttribute("data-placeholder")
    else if @is_multiple
      @default_text = @options.placeholder_text_multiple || @options.placeholder_text || AbstractChosen.default_multiple_text
    else
      @default_text = @options.placeholder_text_single || @options.placeholder_text || AbstractChosen.default_single_text

    @default_text = this.escape_html(@default_text)

    @results_none_found = @form_field.getAttribute("data-no_results_text") || @options.no_results_text || AbstractChosen.default_no_result_text
    @create_option_text = @form_field.getAttribute("data-create_option_text") || @options.create_option_text || AbstractChosen.default_create_option_text

  choice_label: (item) ->
    if @include_group_label_in_selected and item.group_label?
      "<b class='group-name'>#{this.escape_html(item.group_label)}</b>#{item.html}"
    else
      item.html

  mouse_enter: -> @mouse_on_container = true
  mouse_leave: -> @mouse_on_container = false

  input_focus: (evt) ->
    if @is_multiple
      setTimeout (=> this.container_mousedown()), 50 unless @active_field
    else
      @activate_field() unless @active_field

  input_blur: (evt) ->
    if not @mouse_on_container
      @active_field = false
      setTimeout (=> this.blur_test()), 100

  label_click_handler: (evt) =>
    if @is_multiple
      this.container_mousedown(evt)
    else
      this.activate_field()

  results_option_build: (options) ->
    content = ''
    shown_results = 0
    for data in @results_data
      data_content = ''
      if data.group
        data_content = this.result_add_group data
      else
        data_content = this.result_add_option data
      if data_content != ''
        shown_results++
        content += data_content

      # this select logic pins on an awkward flag
      # we can make it better
      if options?.first
        if data.selected and @is_multiple
          this.choice_build data
        else if data.selected and not @is_multiple
          this.single_set_selected_text(this.choice_label(data))

      if shown_results >= @max_shown_results
        break

    content

  result_add_option: (option) ->
    return '' unless option.search_match
    return '' unless this.include_option_in_results(option)

    classes = []
    classes.push "active-result" if !option.disabled and !(option.selected and @is_multiple)
    classes.push "disabled-result" if option.disabled and !(option.selected and @is_multiple)
    classes.push "result-selected" if option.selected
    classes.push "group-option" if option.group_array_index?
    classes.push option.classes if option.classes != ""

    option_el = document.createElement("li")
    option_el.className = classes.join(" ")
    option_el.style.cssText = option.style if option.style
    for attrName of option.data
      if option.data.hasOwnProperty(attrName)
        option_el.setAttribute(attrName, option.data[attrName])
    option_el.setAttribute("role", "option")
    option_el.innerHTML = option.highlighted_html or option.html
    option_el.id = "#{@form_field.id}-chosen-search-result-#{option.data['data-option-array-index']}"
    option_el.title = option.title if option.title

    this.outerHTML(option_el)

  result_add_group: (group) ->
    return '' unless group.search_match || group.group_match
    return '' unless group.active_options > 0

    classes = []
    classes.push "group-result"
    classes.push group.classes if group.classes

    group_el = document.createElement("li")
    group_el.className = classes.join(" ")
    group_el.innerHTML = group.highlighted_html or this.escape_html(group.label)
    group_el.title = group.title if group.title

    this.outerHTML(group_el)

  append_option: (option) ->
    this.select_append_option(option)

  results_update_field: ->
    this.set_default_text()
    this.results_reset_cleanup() if not @is_multiple
    this.result_clear_highlight()
    this.results_build()
    this.winnow_results() if @results_showing

  reset_single_select_options: () ->
    for result in @results_data
      result.selected = false if result.selected

  results_toggle: ->
    if @results_showing
      this.results_hide()
    else
      this.results_show()

  results_search: (evt) ->
    if @results_showing
      this.winnow_results()
    else
      this.results_show()
    @form_field_jq.trigger("chosen:search", {chosen: this})

  winnow_results: (options) ->
    this.no_results_clear()

    results = 0
    exact_result = false
    match_value = false

    query = this.get_search_text()
    escaped_query = query.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&")
    regex = this.get_search_regex(escaped_query)
    exact_regex = new RegExp("^#{escaped_query}$")
    highlight_regex = this.get_highlight_regex(escaped_query)

    for option in @results_data

      option.search_match = false
      results_group = null
      search_match = null
      option.highlighted_html = ''

      if this.include_option_in_results(option)

        if option.group
          option.group_match = false
          option.active_options = 0

        if option.group_array_index? and @results_data[option.group_array_index]
          results_group = @results_data[option.group_array_index]
          results += 1 if results_group.active_options is 0 and results_group.search_match
          results_group.active_options += 1

        text = if option.group then option.label else option.text

        unless option.group and not @group_search
          search_match = this.search_string_match(text, regex)
          option.search_match = search_match?

          if not option.search_match and @search_in_values
            option.search_match = this.search_string_match(option.value, regex)
            match_value = true

          results += 1 if option.search_match and not option.group

          exact_result = exact_result || exact_regex.test option.html

          if option.search_match
            if query.length and not match_value
              startpos = search_match.index
              prefix = text.slice(0, startpos)
              fix    = text.slice(startpos, startpos + query.length)
              suffix = text.slice(startpos + query.length)
              option.highlighted_html = "#{this.escape_html(prefix)}<em>#{this.escape_html(fix)}</em>#{this.escape_html(suffix)}"

            results_group.group_match = true if results_group?

          else if option.group_array_index? and @results_data[option.group_array_index].search_match
            option.search_match = true

    this.result_clear_highlight()

    if results < 1 and query.length
      this.update_results_content ""
      this.fire_search_updated query
      this.no_results query unless @create_option and @skip_no_results
    else
      this.update_results_content this.results_option_build()
      this.fire_search_updated query
      this.winnow_results_set_highlight() unless options?.skip_highlight

    if @create_option and (results < 1 or (!exact_result and @persistent_create_option)) and query.length
      this.show_create_option( query )

  get_search_regex: (escaped_search_string) ->
    regex_string = if @search_contains then escaped_search_string else "(^|\\s|\\b)#{escaped_search_string}[^\\s]*"
    regex_string = "^#{regex_string}" unless @enable_split_word_search or @search_contains
    regex_flag = if @case_sensitive_search then "" else "i"
    new RegExp(regex_string, regex_flag)

  get_highlight_regex: (escaped_search_string) ->
    regex_anchor = if @search_contains then "" else "\\b"
    regex_flag = if @case_sensitive_search then "" else "i"
    new RegExp(regex_anchor + escaped_search_string, regex_flag)

  get_list_special_char: () ->
    chars = []
    chars.push { val: "ae", let: "(ä|æ|ǽ)" }
    chars.push { val: "oe", let: "(ö|œ)" }
    chars.push { val: "ue", let: "(ü)" }
    chars.push { val: "Ae", let: "(Ä)" }
    chars.push { val: "Ue", let: "(Ü)" }
    chars.push { val: "Oe", let: "(Ö)" }
    chars.push { val: "AE", let: "(Æ|Ǽ)" }
    chars.push { val: "ss", let: "(ß)" }
    chars.push { val: "IJ", let: "(Ĳ)" }
    chars.push { val: "ij", let: "(ĳ)" }
    chars.push { val: "OE", let: "(Œ)" }
    chars.push { val: "A", let: "(À|Á|Â|Ã|Ä|Å|Ǻ|Ā|Ă|Ą|Ǎ)" }
    chars.push { val: "a", let: "(à|á|â|ã|å|ǻ|ā|ă|ą|ǎ|ª)" }
    chars.push { val: "C", let: "(Ç|Ć|Ĉ|Ċ|Č)" }
    chars.push { val: "c", let: "(ç|ć|ĉ|ċ|č)" }
    chars.push { val: "D", let: "(Ð|Ď|Đ)" }
    chars.push { val: "d", let: "(ð|ď|đ)" }
    chars.push { val: "E", let: "(È|É|Ê|Ë|Ē|Ĕ|Ė|Ę|Ě)" }
    chars.push { val: "e", let: "(è|é|ê|ë|ē|ĕ|ė|ę|ě)" }
    chars.push { val: "G", let: "(Ĝ|Ğ|Ġ|Ģ)" }
    chars.push { val: "g", let: "(ĝ|ğ|ġ|ģ)" }
    chars.push { val: "H", let: "(Ĥ|Ħ)" }
    chars.push { val: "h", let: "(ĥ|ħ)" }
    chars.push { val: "I", let: "(Ì|Í|Î|Ï|Ĩ|Ī|Ĭ|Ǐ|Į|İ)" }
    chars.push { val: "i", let: "(ì|í|î|ï|ĩ|ī|ĭ|ǐ|į|ı)" }
    chars.push { val: "J", let: "(Ĵ)" }
    chars.push { val: "j", let: "(ĵ)" }
    chars.push { val: "K", let: "(Ķ)" }
    chars.push { val: "k", let: "(ķ)" }
    chars.push { val: "L", let: "(Ĺ|Ļ|Ľ|Ŀ|Ł)" }
    chars.push { val: "l", let: "(ĺ|ļ|ľ|ŀ|ł)" }
    chars.push { val: "N", let: "(Ñ|Ń|Ņ|Ň)" }
    chars.push { val: "n", let: "(ñ|ń|ņ|ň|ŉ)" }
    chars.push { val: "O", let: "(Ò|Ó|Ô|Õ|Ō|Ŏ|Ǒ|Ő|Ơ|Ø|Ǿ)" }
    chars.push { val: "o", let: "(ò|ó|ô|õ|ō|ŏ|ǒ|ő|ơ|ø|ǿ|º)" }
    chars.push { val: "R", let: "(Ŕ|Ŗ|Ř)" }
    chars.push { val: "r", let: "(ŕ|ŗ|ř)" }
    chars.push { val: "S", let: "(Ś|Ŝ|Ş|Š)" }
    chars.push { val: "s", let: "(ś|ŝ|ş|š|ſ)" }
    chars.push { val: "T", let: "(Ţ|Ť|Ŧ)" }
    chars.push { val: "t", let: "(ţ|ť|ŧ)" }
    chars.push { val: "U", let: "(Ù|Ú|Û|Ũ|Ū|Ŭ|Ů|Ű|Ų|Ư|Ǔ|Ǖ|Ǘ|Ǚ|Ǜ)" }
    chars.push { val: "u", let: "(ù|ú|û|ũ|ū|ŭ|ů|ű|ų|ư|ǔ|ǖ|ǘ|ǚ|ǜ)" }
    chars.push { val: "Y", let: "(Ý|Ÿ|Ŷ)" }
    chars.push { val: "y", let: "(ý|ÿ|ŷ)" }
    chars.push { val: "W", let: "(Ŵ)" }
    chars.push { val: "w", let: "(ŵ)" }
    chars.push { val: "Z", let: "(Ź|Ż|Ž)" }
    chars.push { val: "z", let: "(ź|ż|ž)" }
    chars.push { val: "f", let: "(ƒ)" }
    chars

  escape_special_char: (str) ->
    specialChars = this.get_list_special_char()
    for special in specialChars
      str.replace(new RegExp(special.let, "g"), special.val)
    str

  search_string_match: (search_string, regex) ->
    match = regex.exec(search_string)
    match = regex.exec(this.escape_special_char(search_string)) if not @case_sensitive_search && match?
    match.index += 1 if not @search_contains && match?[1] # make up for lack of lookbehind operator in regex
    match

  choices_count: ->
    return @selected_option_count if @selected_option_count?

    @selected_option_count = 0
    for option in @form_field.options
      @selected_option_count += 1 if option.selected

    return @selected_option_count

  choices_click: (evt) ->
    evt.preventDefault()
    this.activate_field()
    this.results_show() unless @results_showing or @is_disabled

  mousedown_checker: (evt) ->
    evt = evt || window.event
    mousedown_type = null
    if (!evt.which and evt.button != undefined)
      evt.which = ( evt.button & 1 ? 1 : ( evt.button & 2 ? 3 : ( evt.button & 4 ? 2 : 0 ) ) )

    switch evt.which
      when 1
        mousedown_type = 'left'
        break
      when 2
        mousedown_type = 'right'
        break
      when 3
        mousedown_type = 'middle'
        break
      else
        mousedown_type = 'other'

    return mousedown_type

  keydown_checker: (evt) ->
    stroke = evt.which ? evt.keyCode
    this.search_field_scale()

    this.clear_backstroke() if stroke != 8 and @pending_backstroke

    switch stroke
      when 8 # backspace
        @backstroke_length = this.get_search_field_value().length
        break
      when 9 # tab
        this.result_select(evt) if @results_showing and not @is_multiple
        @mouse_on_container = false
        break
      when 13 # enter
        evt.preventDefault() if @results_showing
        break
      when 27 # escape
        evt.preventDefault() if @results_showing
        break
      when 32 # space
        evt.preventDefault() if @disable_search
        break
      when 38 # up arrow
        evt.preventDefault()
        this.keyup_arrow()
        break
      when 40 # down arrow
        evt.preventDefault()
        this.keydown_arrow()
        break

  keyup_checker: (evt) ->
    stroke = evt.which ? evt.keyCode
    this.search_field_scale()

    switch stroke
      when 8 # backspace
        if @is_multiple and @backstroke_length < 1 and this.choices_count() > 0
          this.keydown_backstroke()
        else if not @pending_backstroke
          this.result_clear_highlight()
          this.results_search()
        break
      when 13 # enter
        evt.preventDefault()
        this.result_select(evt) if this.results_showing
        break
      when 27 # escape
        this.results_hide() if @results_showing
        break
      when 9, 16, 17, 18, 38, 40, 91
        # don't do anything on these keys
      else
        this.results_search()
        break

  clipboard_event_checker: (evt) ->
    return if @is_disabled
    setTimeout (=> this.results_search()), 50

  container_width: ->
    return @options.width if @options.width?
    return "#{@form_field.offsetWidth}px" if @form_field.offsetWidth > 0
    return "auto"

  include_option_in_results: (option) ->
    return false if @is_multiple and (not @display_selected_options and option.selected)
    return false if not @display_disabled_options and option.disabled
    return false if option.empty
    return false if option.hidden
    return false if option.group_array_index? and @results_data[option.group_array_index].hidden

    return true

  search_results_touchstart: (evt) ->
    @touch_started = true
    this.search_results_mouseover(evt)

  search_results_touchmove: (evt) ->
    @touch_started = false
    this.search_results_mouseout(evt)

  search_results_touchend: (evt) ->
    this.search_results_mouseup(evt) if @touch_started

  outerHTML: (element) ->
    return element.outerHTML if element.outerHTML
    tmp = document.createElement("div")
    tmp.appendChild(element)
    tmp.innerHTML

  get_single_html: ->
    """
      <a class="chosen-single chosen-default">
        <span>#{@default_text}</span>
        <div><b></b></div>
      </a>
      <div class="chosen-drop">
        <div class="chosen-search">
          <input class="chosen-search-input" type="text" autocomplete="off" role="combobox" aria-expanded="false" aria-haspopup="true" aria-autocomplete="list" autocomplete="off" />
        </div>
        <ul class="chosen-results" role="listbox"></ul>
      </div>
    """

  get_multi_html: ->
    """
      <ul class="chosen-choices">
        <li class="search-field">
          <input class="chosen-search-input" type="text" autocomplete="off" role="combobox" placeholder="#{@default_text}" aria-expanded="false" aria-haspopup="true" aria-autocomplete="list" />
        </li>
      </ul>
      <div class="chosen-drop">
        <ul class="chosen-results" role="listbox"></ul>
      </div>
    """

  get_no_results_html: (terms) ->
    """
      <li class="no-results">
        #{@results_none_found} <span>#{this.escape_html(terms)}</span>
      </li>
    """

  get_option_html: ({ value, text }) ->
    """
      <option value="#{value}" selected>#{text}</option>
    """

  get_create_option_html: (terms) ->
    """
      <li class="create-option active-result" role="option"><a>#{@create_option_text}</a> <span>#{this.escape_html(terms)}</span></li>
    """

  # class methods and variables ============================================================

  @browser_is_supported: ->
    return true

  @default_multiple_text: "Select Some Options"
  @default_single_text: "Select an Option"
  @default_no_result_text: "No results for:"
  @default_create_option_text: "Add Option:"
