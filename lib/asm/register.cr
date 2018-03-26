module ASM
  # Based off https://wiki.skullsecurity.org/index.php?title=Registers
  enum Register
    EAX, AX, AH, AL,
    EBX, BX, BH, BL,
    ECX, CX, CH, CL,
    EDX, DX, DH, DL,
    ESI, SI,
    EDI, DI,
    EBP, BP,
    ESP, SP,
    EIP

    # Special register.
    FLAGS
  end
end
