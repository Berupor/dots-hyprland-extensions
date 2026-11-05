import qs.modules.common.models.quickToggles

QuickToggleModel {
    name: "Hello Toggle"
    icon: "waving_hand"
    statusText: toggled ? "Waving" : "Still"
    mainAction: () => { toggled = !toggled }
}
