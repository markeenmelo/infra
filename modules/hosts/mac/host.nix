{
  fleet.hosts.mac = {
    system = "aarch64-darwin";
    darwin = {
      system.stateVersion = 7;
      home-manager.users.marcos.home.stateVersion = "26.11";
    };
  };
}
