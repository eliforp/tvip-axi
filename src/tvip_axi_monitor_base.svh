`ifndef TVIP_AXI_MONITOR_BASE_SVH
`define TVIP_AXI_MONITOR_BASE_SVH
virtual class tvip_axi_monitor_base #(
  type  BASE  = uvm_monitor,
  type  ITEM  = uvm_sequence_item
) extends tvip_axi_component_base #(BASE);
  uvm_analysis_port #(ITEM) address_item_port;
  uvm_analysis_port #(ITEM) request_item_port;
  uvm_analysis_port #(ITEM) response_item_port;

  protected tvip_axi_item           current_address_item;
  protected tvip_axi_payload_store  write_items[$];
  protected tvip_axi_payload_store  response_items[tvip_axi_id][$];

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    address_item_port   = new("address_item_port" , this);
    request_item_port   = new("request_item_port" , this);
    response_item_port  = new("response_item_port", this);
  endfunction

  task run_phase(uvm_phase phase);
    forever @(vif.monitor_cb) begin
      if (!vif.areset_n) begin
        do_reset();
      end
      else begin
        if (get_address_valid()) begin
          monitor_address();
        end
        if (get_write_data_valid()) begin
          monitor_write_data();
        end
        if (get_response_valid()) begin
          monitor_response();
        end
      end
    end
  endtask

  virtual function void end_address(tvip_axi_item item);
    ITEM  temp;
    super.end_address(item);
    $cast(temp, item);
    address_item_port.write(temp);
    if (is_read_component()) begin
      request_item_port.write(temp);
    end
  endfunction

  virtual function void end_write_data(tvip_axi_item item);
    ITEM  temp;
    super.end_write_data(item);
    if (is_write_component()) begin
      $cast(temp, item);
      request_item_port.write(temp);
    end
  endfunction

  virtual function void end_response(tvip_axi_item item);
    ITEM  temp;
    super.end_response(item);
    $cast(temp, item);
    write_item(temp);
    response_item_port.write(temp);
  endfunction

  protected task do_reset();
    if (current_address_item != null) begin
      end_tr(current_address_item);
    end
    current_address_item  = null;

    foreach (write_items[i]) begin
      if (!write_items[i].item.ended()) begin
        end_tr(write_items[i].item);
      end
    end
    write_items.delete();

    foreach (response_items[i, j]) begin
      if (!response_items[i][j].item.ended()) begin
        end_tr(response_items[i][j].item);
      end
    end
    response_items.delete();
  endtask

  protected virtual task monitor_address();
    if (current_address_item == null) begin
      sample_address();
    end
    if ((current_address_item != null) && get_address_ready()) begin
      finish_address();
    end
  endtask

  protected virtual task sample_address();
    tvip_axi_payload_store  payload_store;

    current_address_item  = ITEM::type_id::create("axi_item");
    current_address_item.set_context(configuration, status);

    current_address_item.access_type  = (is_write_component()) ? TVIP_AXI_WRITE_ACCESS : TVIP_AXI_READ_ACCESS;
    current_address_item.id           = get_address_id();
    current_address_item.address      = get_address();
    current_address_item.burst_length = get_burst_length();
    current_address_item.burst_size   = get_burst_size();
    current_address_item.burst_type   = get_burst_type();
    current_address_item.qos          = get_qos();
    begin_address(current_address_item);

    payload_store = tvip_axi_payload_store::create(current_address_item);
    if (is_write_component()) begin
      write_items.push_back(payload_store);
    end
    response_items[current_address_item.id].push_back(payload_store);
  endtask

  protected virtual task finish_address();
    end_address(current_address_item);
    current_address_item  = null;
  endtask

  protected virtual task monitor_write_data();
    if ((write_items.size() > 0) && (!write_items[0].item.write_data_began())) begin
      begin_write_data(write_items[0].item);
    end
    if ((write_items.size() > 0) && get_write_data_ready()) begin
      sample_write_data();
    end
  endtask

  protected virtual task sample_write_data();
    write_items[0].store_write_data(get_write_data(), get_strobe());
    if (get_write_data_last()) begin
      write_items[0].pack_write_data();
      end_write_data(write_items[0].item);
      void'(write_items.pop_front());
    end
  endtask

  protected virtual task monitor_response();
    tvip_axi_id id  = get_response_id();
    if ((!response_items.exists(id)) || (response_items[id].size() == 0)) begin
      return;
    end
    if (!response_items[id][0].item.response_began()) begin
      begin_response(response_items[id][0].item);
    end
    if (get_response_ready()) begin
      sample_response(id);
    end
  endtask

  protected virtual task sample_response(tvip_axi_id id);
    response_items[id][0].store_response(get_response(), get_read_data());
    if (get_response_last()) begin
      response_items[id][0].pack_response();
      end_response(response_items[id][0].item);
      void'(response_items[id].pop_front());
    end
  endtask

  `tue_component_default_constructor(tvip_axi_monitor_base)
endclass
`endif
